function y = fixgaps(x)
%% 
% FIXGAPS Linearly interpolates gaps in a time series
% y=FIXGAPS(x) linearly interpolates over NaN
% in the input time series (may be complex), but ignores
% trailing and leading NaN.
%
% Syntax:  YOUT=FIXGAPS(YIN)
%
% Inputs:
%    x - NxCh data matrix
%
% Outputs:
%    y - NxCh matrix with interpolated gaps
%
% Hoameng Ung 9/12/2016
% Modified to interpolate over each channels
% Based on R. Pawlowicz 6/Nov/99

y = x;
for i = 1:size(x,2)
    x2 = x(:,i);
    y2=x2;

    bd=isnan(x2);
    gd=find(~bd);

    bd([1:(min(gd)-1) (max(gd)+1):end])=0;
    y2(bd)=interp1(gd,x(gd),find(bd));
    y(:,i) = y2;
end