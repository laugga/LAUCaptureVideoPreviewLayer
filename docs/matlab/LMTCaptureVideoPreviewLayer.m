%% LMTCaptureVideoPreviewLayer 
%%
% Filter test-image using a gaussian filter kernel and display it. 
% Copyright 2016 Luis Laugga

DOWNSAMPLING_FACTOR = 4;
SIGMA = 3;
fs = filterSize(SIGMA);
gaussianFilterKernel = Gaussian2dMatrix(SIGMA);

testImage = readTestImage('test-image.png', DOWNSAMPLING_FACTOR);

% Normal 2d convolution
filteredTestImage1stPass = imfilter(testImage, gaussianFilterKernel, 'conv');
filteredTestImage2ndPass = imfilter(filteredTestImage1stPass, gaussianFilterKernel, 'conv'); % 2nd gaussian filter pass (better than a bigger kernel?)
writeTestImage(filteredTestImage2ndPass, 'filtered-test-image-2d-convolution.png', DOWNSAMPLING_FACTOR);
% imshow(filteredTestImage2ndPass);

% Using separable filters, with two one-dimensional Gaussian blurs
horizontalGaussianFilterKernel = HorizontalGaussian2dMatrix(gaussianFilterKernel);
verticalGaussianFilterKernel = VerticalGaussian2dMatrix(gaussianFilterKernel);
filteredTestImage1stPassH = imfilter(testImage, horizontalGaussianFilterKernel, 'conv');
filteredTestImage1stPassV = imfilter(filteredTestImage1stPassH, verticalGaussianFilterKernel, 'conv');
filteredTestImage2ndPassH = imfilter(filteredTestImage1stPassV, horizontalGaussianFilterKernel, 'conv');
filteredTestImage2ndPassV = imfilter(filteredTestImage2ndPassH, verticalGaussianFilterKernel, 'conv');
writeTestImage(filteredTestImage2ndPass, 'filtered-test-image-separable-filters.png', DOWNSAMPLING_FACTOR);
%imshow(filteredTestImage2ndPassV);

% Gaussian(0,SIGMA);

% Cook(0,SIGMA,filterRadius(SIGMA));
%cookFilterKernel = Cook2dMatrix(SIGMA);
%filteredTestImage1CookKernel = imfilter(testImage1, cookFilterKernel);
%imshow(filteredTestImage1CookKernel);

%gaussian = fspecial('gaussian', [fs,fs],SIGMA);
%gaussian
%filtered = imfilter(testImage1, gaussian);
%imshow(filtered);
%filteredBetter = imgaussfilt(testImage1, SIGMA);
%imshow(filteredBetter)

function dim = readTestImage(imageName, DOWNSAMPLING_FACTOR)
im = imread(imageName);
dim = imresize(im, 1.0/DOWNSAMPLING_FACTOR, 'bilinear');
end

function writeTestImage(dim, imageName, DOWNSAMPLING_FACTOR)
uim = imresize(dim, DOWNSAMPLING_FACTOR, 'bilinear');
imwrite(uim, imageName);
end

function fs = filterSize(SIGMA)
fs = 2*ceil(2*SIGMA)+1; % or 2*ceil(2*SIGMA)+1
end

function fr = filterRadius(SIGMA)
fr = ceil(filterSize(SIGMA)/2);
end

function s = sigma(filterSize) % filterSize must be an odd and integer nunber
s = (filterSize-1)/4;
end

function g = Gaussian(x, SIGMA)
g = exp(-1 * (x ^ 2)/(2 * (SIGMA ^ 2)))
end

function c = Cook(x, SIGMA, radius) % Truncated gaussian filter with smoother dropoff
if x <= radius
c = exp(-1 * (x^2)/(2*(SIGMA^2))) - exp(-1 * (radius^2)/(2*(SIGMA^2)))
else
c = 0;
end
end

function g2d = Gaussian2d(x, y, SIGMA)
g2d = exp(-1 * ( ((x^2)/(2*(SIGMA^2))) + ((y^2)/(2*(SIGMA^2))) ) );
end

function c2d = Cook2d(x, y, SIGMA, radius) % Truncated gaussian filter with smoother dropoff
if x <= radius && y <= radius
c2d = exp(-1 * ( ((x^2)/(2*(SIGMA^2))) + ((y^2)/(2*(SIGMA^2))) ) ) - exp(-1 * (radius^2)/(2*(SIGMA^2)));
else
c2d = 0;
end
end

function g2dm = Gaussian2dMatrix(SIGMA)
fs = filterSize(SIGMA);
fr = filterRadius(SIGMA);
g2dm = zeros(fs, fs);
for x = 1:fs
    for y = 1:fs
        g2dm(y,x) = Gaussian2d(x-fr, y-fr, SIGMA);
    end
end
g2dm = (g2dm / sum(sum(g2dm))) % normalize matrix so that the final weights will sum to 1
end

function hg2dm = HorizontalGaussian2dMatrix(g2dm)
[m,n] = size(g2dm);
hg2dm = zeros(m, n);
for x = 1:m
    hg2dm(1,x) = g2dm(x, x);
end
hg2dm = (hg2dm.^0.5) % sqrt elements so horizontal x vertical = gaussian 2d matrix weights
end

function vg2dm = VerticalGaussian2dMatrix(g2dm)
[m,n] = size(g2dm);
vg2dm = zeros(m, n);
for y = 1:n
    vg2dm(y,1) = g2dm(y, y);
end
vg2dm = (vg2dm.^0.5) % sqrt elements so horizontal x vertical = gaussian 2d matrix weights
end

function c2dm = Cook2dMatrix(SIGMA)
fs = filterSize(SIGMA);
fr = filterRadius(SIGMA);
c2dm = zeros(fs, fs);
for x = 1:fs
    for y = 1:fs
        c2dm(y,x) = Cook2d(x-fr, y-fr, SIGMA, fr);
    end
end
c2dm = (c2dm / sum(sum(c2dm))) % normalize matrix so that the final weights will sum to 1
end



