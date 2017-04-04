% convert blurTracingCadidates to b/w

%baseDir = pwd;
%subDir = 'Fruits';
%cd([baseDir, '/', subDir]);

d = dir('*.jpg');
for tmp = 1:size(d)
    if ~strcmp(d(tmp).name,'.') & ~strcmp(d(tmp).name,'..') & ~strcmp(d(tmp).name,'.DS_store')
        d(tmp).name
        srcIm = imread(d(tmp).name);
        srcIm = rgb2gray(srcIm);
        imwrite(srcIm, d(tmp).name);
    end
end