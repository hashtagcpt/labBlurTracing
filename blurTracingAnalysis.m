clear all

% local RMS pixel stdev
stdev = 8;

calibrated = 1;
blurLevels = [64 16 8 4 2];
%blurLevels = 64; % test code

numImages = 10;
blocks = 1;

% compute some shit
%winRect = [0 0 1680 1050];
winRect = [0 0 1920 1200];

natOffset = 256;

sigma = [64 32 16 8 4 2]; % list of standard deviations for gaussian derivative filters
theta = [0 45 90 135]; % list of orientations - NB take as value, so orientation >180 sign ignored

% set sample sizes
sampleSize = [256 128 64 32 16 8];

% directories
mainDir = '/home/taylorcp/Clouds/Dropbox/Exp/bexlab/localSlopeImageStats';
dataDir = '/home/taylorcp/Clouds/Dropbox/Exp/bexlab/localSlopeImageStats/data/';
if calibrated
    imType = 'McGill';
    imFmt = '*.tif';
else
    imType = 'Web';
    imFmt = '*.jpg';
end

imDir = [mainDir, '/blurTracing', imType];
dataDir = [dataDir, '/', imType];

cd(dataDir)
for imIndx = 1:numImages
    cd(imDir)
    d = dir(imFmt);
    natIm = double(imread(d(imIndx).name));
    if ~calibrated
        scaleFactor = size(natIm) ./ [1024 768];       
        natIm = imresize(natIm, 1./max(scaleFactor));
    end
    % get natural image location on screen and make 0,0 top left of
    % the image
    natImSize = size(natIm);
    natImRect = CenterRect([0 0 natImSize(2) natImSize(1)], winRect) - [natOffset 0 natOffset 0]; 

    fullMaskIm = zeros(natImSize);  % test code
    
    % compute local slope of each image
    [m,c] = localSlope(natIm); % get image local slope matrix
    

    % take out low local RMS contrast
    gradient = localRMS(double(natIm),stdev);
    ind = find(gradient < 5);
    gradient
    gradient(ind) = 0;

    ind = find(gradient >= 5); 
    gradient(ind) = 1;
    m = m.*gradient;

    break
    
    for sizeCtr = 1:length(sampleSize)
        % get image local slope matrix
        [m,c] = localSlope(natIm);

        % take out low local RMS contrast
        gradient = localRMS(double(natIm),stdev);
        ind = find(gradient < 5); gradient(ind) = 0;

        ind = find(gradient >= 5); gradient(ind) = 1;
        m = m.*gradient;
        % get traced regions
        [r,c]= find(traceData(imIndx).tracedPoints == -1);
        r = [0; r]; c = [0; c];
        for tmp = 1:length(unique(r))
            points = [];
            if length(unique(r)) <= 1
                slopeData(imIndx).localSlope = [];
            else    
                pointsList = (r(tmp)+1):(r(tmp+1)-1);
            end
            points = traceData(imIndx).tracedPoints(pointsList,:);
            if size(points,1) > 0
                points = [points; points(1,:)];
                % load the image
                points(:,1) = points(:,1) - natImRect(1);
                points(:,2) = points(:,2) - natImRect(2);

                % make a layer mask
                maskIm = zeros(size(natIm));
                maskIm = roipoly(maskIm, points(:,1), points(:,2));
                fullMaskIm = fullMaskIm + maskIm;    % test code 
                mMask = m .* maskIm;
                mMask = mMask(:);
                ind = find(mMask == 0 | isnan(mMask));
                mMask(ind) = [];
                slopeData(imIndx).localSlope(tmp) = mean(mMask);
                allLocalSlopes(counter) = mean(mMask);
                allLocalSlopesStd(counter) = std(mMask);
                counter = counter + 1;
            end
        end
    end
    cd(mainDir);
    eval(sprintf('als%s = allLocalSlopes;', num2str(blurLevels(blurIndx))));
    %eval(sprintf('alsStd%s = allLocalSlopesStd;', num2str(blurLevels(blurIndx))));    

    %eval(sprintf('save %s_final_%s_%s_localRMS_%s.mat als%s alsStd%s', obs{tmpObs}, num2str(blurLevels(blurIndx)), num2str(stdev), imType, num2str(blurLevels(blurIndx)), num2str(blurLevels(blurIndx))));
end
   