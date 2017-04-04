function gauss2D = Gaussian2D(stdev, location, imSize, imOri)

if nargin==3
    imOri=0;
else
    imTheta=imOri*pi/180; % convert to radians
end

if length(stdev)==1;    stdev(2)=stdev(1);          end
if length(location)==1; location(2)=location(1);    end
if length(imSize)==1;   imSize(2)=imSize(1);        end

[X,Y]=meshgrid(1-location(2):imSize(2)-location(2),1-location(1):imSize(1)-location(1)); 

Xrot=sin(imOri)*X+cos(imOri)*Y;
Yrot=sin(imOri)*Y-cos(imOri)*X;
%gauss2D=exp(-(X.^2/(2*stdev(1).^2))).*exp(-(Y.^2/(2*stdev(2).^2)));
gauss2D=exp(-(Xrot.^2/(2*stdev(1).^2))).*exp(-(Yrot.^2/(2*stdev(2).^2)));