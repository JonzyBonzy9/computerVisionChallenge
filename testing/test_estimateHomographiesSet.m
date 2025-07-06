% add src to path
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', 'src'));

% get path to image folder
folderPath = fullfile(scriptDir, '..', 'data', 'Datasets', 'Frauenkirche');
fileList = dir(fullfile(folderPath, '*.jpg'));
if isempty(fileList)
    error('No image files found.');
end

% Read images into a cell array
imageArray = cell(1, length(fileList));
for i = 1:length(fileList)
    % Load image
    imageArray{i}.data = imread(fullfile(fileList(i).folder, fileList(i).name));
    
    % Extract filename without extension
    [~, nameWithoutExt, ~] = fileparts(fileList(i).name);
   
    % Try parsing date in two possible formats
    try
        dt = datetime(nameWithoutExt, 'InputFormat', 'MM_yyyy');
    catch
        try
            dt = datetime(nameWithoutExt, 'InputFormat', 'yyyy_MM');
        catch
            error('Could not parse date from filename: %s', fileList(i).name);
        end
    end
    % Assign datetime as ID
    imageArray{i}.id = dt;
end

% get outputs
output = estimateHomographiesSet.estimateHomographiesSuccessive(imageArray);

% plot results
for i = 1:length(output)
    % Get image data and transformation
    img1 = output{i}.image1;
    img2 = output{i}.image2;
    H = output{i}.H;
    score = output{i}.inlierRatio;
    num_points = length(output{i}.inlierPts1);

    % Warp image 2 to image 1's space using the homography
    tform = projective2d(H);
    warpedImg2 = imwarp(img2, tform, 'OutputView', imref2d(size(img1)));

    % Show overlay using imshowpair
    figure;
    imshowpair(img1, warpedImg2, 'blend');
    title(sprintf('Pair: %s <-> %s | inlierRatio: %.2f | #inlierPoints: %d', ...
        output{i}.id1, output{i}.id2, score,num_points), ...
        'Interpreter', 'none');

    % pause until user hits a key
    disp('Press any key to continue to the next image pair...');
    pause;
    close;
end

