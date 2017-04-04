function [] = blurTracing
% Samsung SyncMaster T240HD
% 
% Dimensions 51cm by 31cm, resolution 1920 by 1200

mainDir = '~/Exp/bexlab/blurTracing';
dataDir = '~/Exp/bexlab/blurTracing/data/';
cd(mainDir);

whichScreen=max(Screen('Screens'));            % display # for stimuli

% user prompts 
prompt = {'initials:', 'calibrated images:', 'mean blur level:'};
dlg_title = 'Blur Tracing';
def = {'ABC', '0', '1'};
num_lines = 1;
answer = inputdlg(prompt,dlg_title,num_lines,def); % read in parameters from GUI
% user answers
obs=char(answer(1,1)); % subject ID
%ageYrs=str2num(char(answer(2,1))); % subject age
%nTrials=str2num(char(answer(3,1))); %# times to repeat measurement
calibrated=str2num(char(answer(2,1))); % use McGill images?
if calibrated
    imType = 'McGill';
else
    imType = 'Web';
end

curStimLevel=str2num(char(answer(3,1))); % mean blur
if curStimLevel == 1
    curStimLevel = 64;
elseif curStimLevel == 2
    curStimLevel = 16;
elseif curStimLevel == 3
    curStimLevel = 8;
elseif curStimLevel == 4
    curStimLevel = 4;    
elseif curStimLevel == 5
    curStimLevel = 2;
else
    warning('Invalid mean blur level specified. Use a value from 1-5.');
    return;
end

% gamma correction for screen and other params
gammaVals=[2.0 2.0 2.0]; 
backgroundCol=[127 127 127];

% PTB screen setup 
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible'); % request 32 bit per pixel for high res contrast
PsychImaging('AddTask', 'General', 'EnablePseudoGrayOutput'); % enable bit stealing
PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma'); % use PTB gamma correction
[window winRect] = PsychImaging('OpenWindow', whichScreen, 0.5); % open screen
Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); % use alpha blending
PsychColorCorrection('SetEncodingGamma', window, 1./gammaVals); % set up gamma corection

% get total window size
[sWidth, sHeight] = Screen('WindowSize', window); % screen parameters
centerXY = [sWidth/2 sHeight/2];


% experiment params
% Natural Images -- use McGill Images?
if calibrated
    imType = 'McGill';
    imDir = './blurTracingMcGill';
    fileType = '*.tif';
else
    imType = 'Web';
    imDir = './blurTracingWeb';
    fileType = '*.jpg';
end

% Dead Leaves params
meanBlur = [2 4 8 16];  % make mean blur list
stdevBlur=0.25;         % list of ranges of blur +/- #octaves
frameDiameter=256;      % screen area for blurred dots
edgeOffset=256;         % offset from screen edge
nDots=128;              % number of dots on screen
srcDotSD=[4 32];        % min and max pixel width and height of original, unfiltered oval            

% dead leaves window centers
centerXdots=winRect(3)-frameDiameter-edgeOffset;
centerYdots=winRect(2)+round((winRect(4)-winRect(2))/2);

% gaussian dot parameters
srcDotSize=4*max(srcDotSD);
gaussDot=zeros([srcDotSize srcDotSize 4]);
dotRect=SetRect(0,0,srcDotSize,srcDotSize);
filtDot=zeros([srcDotSize srcDotSize 4]);

% filter parameters
filtRadius=round(srcDotSize/2);
[X,Y]=meshgrid(-filtRadius:-filtRadius+srcDotSize-1,-filtRadius:-filtRadius+srcDotSize-1);                      % 2D matrix of radial distances from centre
Xsqd=X.^2;
Ysqd=Y.^2;
radDist=(Xsqd+Ysqd).^0.5;       % radial distance from centre
radDist=fftshift(radDist);      % experiment and data paths

radDistSqd=radDist.^2;
radDist(1,1)=0.5;

natOffset = 256; % center padding in pixels between the dead leaves and the natural image

% are you ready?
Screen(window,'TextSize',24); % parameters for on-screen messages
Screen('DrawText',window,'Drag mouse around areas of blur that match the blur of the dead leaves.',50,50,0); % message to observer
textToObserver=sprintf('Screen Parameters %d by %d pixels at %3.2f Hz. Press the mouse to start.', winRect(3)-winRect(1),winRect(4)-winRect(2), Screen('FrameRate',window));
Screen('DrawText', window, textToObserver, 50, 100, 0, backgroundCol);
Screen('DrawText', window, 'Click on dead leaves for another sample image.', 50, 150, 0, backgroundCol);
Screen('DrawText', window, 'Click in the box on the left edge for the next image.', 50, 200, 0, backgroundCol);

Screen('Flip', window);

% wait for click
while (1) % loop until subject presses mouse button
    [x,y,buttons] = GetMouse(window);
    if buttons(1); break; end
end
clear x y buttons

% change dir and get image files
cd(imDir);
d = dir(fileType);

for imNum = 1:size(d)
    % init traceData
    traceData(imNum).tracedPoints = [];
    
    % line code
    notDone = 1; doneRect=([0 0 100 winRect(4)]); % finishing conditions
    Screen(window,'DrawLine', 0, doneRect(3), 0, doneRect(3), doneRect(4), 2);
        
    ShowCursor('CrossHair' , window)


    % read in and compute natural image rect    sca
    
    natIm = imread(d(imNum).name);
    if ~calibrated
        scaleFactor = size(natIm) ./ [1024 768];       
        natIm = imresize(natIm, 1./max(scaleFactor));
    end
    natImSize = size(natIm);
    natImRect = CenterRect([0 0 natImSize(2) natImSize(1)], winRect) - [natOffset 0 natOffset 0]; 
    
    % draw natural image
    natTex=Screen('MakeTexture', window, natIm);       % write image to texture
    Screen('DrawTexture', window, natTex, [], natImRect); 
    
    blurDistribution=curStimLevel*zeros([1 nDots]);
   
    blurCut=curStimLevel;

    blurParamVect=2.^(log2(blurCut)+blurDistribution); % gaussian blurs for test image
    blurParamVect(blurParamVect<1)=1;
             
    sizeVect = 2*(srcDotSD(1)+round(rand(2,nDots)*(srcDotSD(2)-srcDotSD(1))).^2); % 2D set to random height and widths
    standColVect = uint8(round(rand(3,nDots)*255)); % random set of colors for ellipses
    for index=1:nDots
        baseDot=exp(-(Xsqd/sizeVect(1,index))).*exp(-(Ysqd/sizeVect(2,index))); % Gaussian ellipse
        baseDotFFT=fft2(double(baseDot>0.6444));    % thresholded to make sharp ellipse

        gaussDot(:,:,1)=standColVect(1,index); % set RGB to required color
        gaussFilter = exp(-(radDistSqd/(2*blurParamVect(index).^2))); % Gaussian Blur    
        gaussFilter(1,1)=0; % zero DC

        alphalayer=real(ifft2(baseDotFFT.*gaussFilter));
        alphalayer=alphalayer-min(alphalayer(:)); % zero min
        gaussDot(:,:,4)=255*alphalayer/max(alphalayer(:)); % scale 0-255
        dotTex(index)=Screen('MakeTexture', window, gaussDot);
    end
    
    destRect=zeros([4 nDots]); % set of destination rects
    destRect(1,:)=Randi(frameDiameter,[1,nDots])-frameDiameter/2+centerXdots-mean(srcDotSize)/2;    % position dots relative to center of screen
    destRect(2,:)=Randi(frameDiameter,[1,nDots])-frameDiameter/2+centerYdots-mean(srcDotSize)/2;
    destRect(3:4,:)=destRect(1:2,:)+srcDotSize;
    
    % compute the dlRect
    dlRect = [min(destRect(1,:)) min(destRect(2,:)) max(destRect(3,:)) max(destRect(4,:))];
    
    dotOris = rand(1,nDots)*360; % set of random orientations
    Screen('DrawTextures', window, dotTex, dotRect, destRect, dotOris); % draw all the overlapping ellipses

    % draw it.    
    Screen('Flip', window,0, 1);
  
    % test period
    while (1) % loop until subject presses mouse button
        [x,y,buttons] = GetMouse(window);
        if buttons(1); break; end
    end
    while notDone
        % tracing
        notDoneTracing = 1;
        [mouseX, mouseY, buttons] = GetMouse(window); % trace the observer's curve on screen
        if isinrect(mouseX, mouseY, natImRect) & notDone & buttons(1)
            traceData(imNum).tracedPoints = [traceData(imNum).tracedPoints ; mouseX mouseY]; %#ok<AGROW> 

                %traceData(imNum).tracedPoints = [mouseX mouseY]; % grow a list of mouse coordinates
            if isinrect(mouseX, mouseY, natImRect)
                Screen(window,'DrawLine', 255, mouseX,mouseY,mouseX,mouseY);
                Screen('Flip', window, 0, 1);% Set the 'dontclear' flag of Flip to 1 to prevent erasing the frame-buffer:
            else
                Screen(window,'DrawLine',127,mouseX,mouseY,mouseX,mouseY);
                Screen('Flip', window, 0, 1);% Set the 'dontclear' flag of Flip to 1 to prevent erasing the frame-buffer:
            end
            while notDoneTracing
                [x,y,buttons] = GetMouse(window);	% loop until subject releases mouse button
                if ~buttons(1)
                    traceData(imNum).tracedPoints = [ traceData(imNum).tracedPoints ; -1  -1];
                    notDoneTracing = 0;
                end
                if (x ~= mouseX | y ~= mouseY) & isinrect(mouseX, mouseY, natImRect) 
                    traceData(imNum).tracedPoints = [ traceData(imNum).tracedPoints ; min(x,winRect(3))  y]; %#ok<AGROW> 
                    [numPoints, two]=size( traceData(imNum).tracedPoints);
                    % Only draw the most recent line segment without erasing on Flip
                    Screen('DrawLine',window,[128 255 128], traceData(imNum).tracedPoints(numPoints-1,1), traceData(imNum).tracedPoints(numPoints-1,2), traceData(imNum).tracedPoints(numPoints,1), traceData(imNum).tracedPoints(numPoints,2),5);
                    Screen('Flip', window, 0, 1);% ...we ask Flip to not clear the framebuffer after flipping:
                    mouseX = x; mouseY = y;
                end                
            end
        end
        % new dead leaves sample      
        [mouseX, mouseY, buttons] = GetMouse(window); % trace the observer's curve on screen        
      
        if ~isinrect(mouseX, mouseY, natImRect) & ~isinrect(mouseX, mouseY, doneRect) & buttons(1)
            % compute the dlRect            
            dlRect = [min(destRect(1,:)) min(destRect(2,:)) max(destRect(3,:)) max(destRect(4,:))];
            dlBlankTex=Screen('MakeTexture', window, 127.*ones(dlRect(4),dlRect(3)));       % write noise to texture
            Screen('DrawTexture', window, dlBlankTex, [], dlRect);
            Screen('Close', dlBlankTex);
            Screen('Flip', window,0,1);
            
            blurDistribution=curStimLevel*zeros([1 nDots]);
            blurCut=curStimLevel;
            blurParamVect=2.^(log2(blurCut)+blurDistribution); % gaussian blurs for test image
            blurParamVect(blurParamVect<1)=1;

            sizeVect = 2*(srcDotSD(1)+round(rand(2,nDots)*(srcDotSD(2)-srcDotSD(1))).^2); % 2D set to random height and widths
            standColVect = uint8(round(rand(3,nDots)*255)); % random set of colors for ellipses
            for index=1:nDots
                baseDot=exp(-(Xsqd/sizeVect(1,index))).*exp(-(Ysqd/sizeVect(2,index))); % Gaussian ellipse
                baseDotFFT=fft2(double(baseDot>0.6444));    % thresholded to make sharp ellipse

                gaussDot(:,:,1)=standColVect(1,index); % set RGB to required color
                gaussFilter = exp(-(radDistSqd/(2*blurParamVect(index).^2))); % Gaussian Blur    
                gaussFilter(1,1)=0; % zero DC

                alphalayer=real(ifft2(baseDotFFT.*gaussFilter));
                alphalayer=alphalayer-min(alphalayer(:)); % zero min
                gaussDot(:,:,4)=255*alphalayer/max(alphalayer(:)); % scale 0-255
                dotTex(index)=Screen('MakeTexture', window, gaussDot);
            end
            destRect=zeros([4 nDots]); % set of destination rects
            destRect(1,:)=Randi(frameDiameter,[1,nDots])-frameDiameter/2+centerXdots-mean(srcDotSize)/2;    % position dots relative to center of screen
            destRect(2,:)=Randi(frameDiameter,[1,nDots])-frameDiameter/2+centerYdots-mean(srcDotSize)/2;
            destRect(3:4,:)=destRect(1:2,:)+srcDotSize;
            dotOris = rand(1,nDots)*360; % set of random orientations
            Screen('DrawTextures', window, dotTex, dotRect, destRect, dotOris); % draw all the overlapping ellipses
            Screen('Close', dotTex);
            % draw it.    
            Screen('Flip', window,0,1);
        end
        
        [mouseX, mouseY, buttons] = GetMouse(window); % trace the observer's curve on screen
        if isinrect(mouseX, mouseY, doneRect) & buttons(1)
            notDone = 0;
            traceData(imNum).tracedPoints = [ traceData(imNum).tracedPoints ];

            natTex=Screen('MakeTexture', window, 127.*ones(winRect(4),winRect(3)));       % write noise to texture
            Screen('DrawTexture', window, natTex, [], winRect);
            Screen('Close', natTex);
            Screen('Flip', window,0,1);
        else
            notDone = 1; % not done tracing with this image / blur level
            natTex=Screen('MakeTexture', window, natIm);       % write natural image to texture
            Screen('DrawTexture', window, natTex, [], natImRect);
            Screen('Close', natTex);
            Screen('Flip', window,0,1);  
        end
    end
    imNum = imNum + 1;
end

% create data file name:
cd([dataDir imType]);

d=dir('*.mat');
numfiles=length(d);
gotName=0;
N=0;
while(gotName==0)
   N=N+1;
   eval(sprintf('filename=[obs,''_'',num2str(curStimLevel),''_blurTracing%s_%s.mat''];', imType, num2str(N)));
   
   foundName=0;
   for kk=1:numfiles
       tmp=d(kk).name;
       foundName=strcmp(lower(filename),lower(tmp));
       if(foundName==1)
           break;
       end;
   end;
   if foundName==0
       gotName=1;
   end;
end;
Screen('CloseAll'); % clear screen
eval(sprintf('save %s traceData curStimLevel winRect', filename));
fprintf('Data was saved in file %s\n',filename);
cd(mainDir);
return;

