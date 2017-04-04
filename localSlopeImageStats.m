clear all

% local RMS pixel stdev
stdev = 32;

calibrated = 0;
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

% matlabpool(4);
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


    % take out low local RMS contrasts
    gradient = localRMS(double(natIm),stdev);
    ind = find(gradient < 5);
    gradient(ind) = 0;
    % leave in low local RMS contrasts
    ind = find(gradient >= 5); 
    gradient(ind) = 1;
    m = m.*gradient;

    % number of samples to take
    nSamples = 500;

    for sizeCtr = 1:length(sampleSize)
        % get image local slope matrix
        [m,c] = localSlope(natIm);
        % init local slope value store
        localSlopeValues = [];
        sampleRect = [0 0 sampleSize(sizeCtr) sampleSize(sizeCtr)];
        for sampleCtr = 1:nSamples
            % select a random center point
            sampX = randi(size(natIm+sampleSize(sizeCtr),1));
            sampY = randi(size(natIm+sampleSize(sizeCtr),2));
            
            sampleRect = CenterRectOnPoint(sampleRect, sampX, sampY);
            % make a layer mask
            maskIm = zeros(size(natIm));
            maskIm = roipoly(maskIm, [sampleRect(1) sampleRect(3) sampleRect(1)+sampleSize(sizeCtr) sampleRect(3)+sampleSize(sizeCtr)],...
                [sampleRect(2) sampleRect(4) sampleRect(2)+sampleSize(sizeCtr) sampleRect(4)+sampleRect(1)+sampleSize(sizeCtr)]);
            % mask out the local slopes
            mMask = m .* maskIm;
            mMask = mMask(:);
            % get rid of 0's and NaNs
            ind = find(mMask == 0 | isnan(mMask));
            mMask(ind) = [];
            % make a list of local slope values
            localSlopeValues = [localSlopeValues; mMask];          
        end
        % save the local slopes
        cd(dataDir)
        fprintf('finished sampleSize_%s_%s.mat...\n', num2str(sampleSize(sizeCtr)), num2str(imIndx))        
        eval(sprintf('save sampleSize_%s_%s.mat localSlopeValues', num2str(sampleSize(sizeCtr)), num2str(imIndx)));      
    end
end
matlabpool close
cd(mainDir)