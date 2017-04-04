fStr = 'sampleSize_';
sampleSizes = [8 16 32 64 128 256];

sampleSizes = 32;


nBlocks = 10;
nVals = 100000; % number of values for histogram
nBins = 1000; % number of bins in the histogram
steps = 1; % number of sampled steps for histogram

for sizeCtr = 1:length(sampleSizes)
    eval(sprintf('summaryLocalSlope%s = [];', num2str(sampleSizes(sizeCtr))));
    for nBlocksCtr = 1:nBlocks
        eval(sprintf('load %s%s_%s.mat', fStr, num2str(sampleSizes(sizeCtr)),...
            num2str(nBlocksCtr))); 
        eval(sprintf('summaryLocalSlope%s = [summaryLocalSlope%s; localSlopeValues];',...
            num2str(sampleSizes(sizeCtr)), num2str(sampleSizes(sizeCtr))));
    end 
    eval(sprintf('summaryLocalSlope%s = summaryLocalSlope%s(1:nVals);',...
        num2str(sampleSizes(sizeCtr)),num2str(sampleSizes(sizeCtr))));
    eval(sprintf('[nv%s, xc%s] = hist(summaryLocalSlope%s, nBins);', num2str(sampleSizes(sizeCtr)),...
        num2str(sampleSizes(sizeCtr)), num2str(sampleSizes(sizeCtr))));
    eval(sprintf('xc%s = fliplr(-1*xc%s(1:steps:nBins));',...
        num2str(sampleSizes(sizeCtr)), num2str(sampleSizes(sizeCtr))));
    eval(sprintf('nv%s = nv%s(1:steps:nBins) ./ sum(nv%s);',...
        num2str(sampleSizes(sizeCtr)), num2str(sampleSizes(sizeCtr)), num2str(sampleSizes(sizeCtr)))); 
end
