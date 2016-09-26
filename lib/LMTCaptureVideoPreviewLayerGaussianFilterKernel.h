/*
 
 LMTCaptureVideoPreviewLayerGaussianFilterKernel.h
 LMTCaptureVideoPreviewLayer
 
 Copyright (c) 2016 Luis Laugga.
 Some rights reserved, all wrongs deserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
*/

#ifndef LMTCaptureVideoPreviewLayerGaussianFilterKernel_h
#define LMTCaptureVideoPreviewLayerGaussianFilterKernel_h

/* 
 This values are generated from the matlab script:
 docs/matlab/LMTCaptureVideoPreviewLayer.m
 See project documentation for more details
 */

// Number of generated filter kernels
static unsigned int const kGaussianFilterKernelCount = 11;

// For each step [0,1] there's a different kernel.
// These kernels are used to animate between filter intensity values
static float const kGaussianFilterKernel[11][16] = {
    { /* t */ 0.000000, /* sigma */ 0.250000, /* size */ 3, /* weights */ 0.000335,0.999330,0.000335 },
    { /* t */ 0.100000, /* sigma */ 0.267500, /* size */ 3, /* weights */ 0.000922,0.998157,0.000922 },
    { /* t */ 0.200000, /* sigma */ 0.320000, /* size */ 3, /* weights */ 0.007463,0.985075,0.007463 },
    { /* t */ 0.300000, /* sigma */ 0.407500, /* size */ 3, /* weights */ 0.044826,0.910347,0.044826 },
    { /* t */ 0.400000, /* sigma */ 0.530000, /* size */ 5, /* weights */ 0.000604,0.125954,0.746884,0.125954,0.000604 },
    { /* t */ 0.500000, /* sigma */ 0.687500, /* size */ 5, /* weights */ 0.008432,0.201455,0.580226,0.201455,0.008432 },
    { /* t */ 0.600000, /* sigma */ 0.880000, /* size */ 5, /* weights */ 0.034355,0.238349,0.454591,0.238349,0.034355 },
    { /* t */ 0.700000, /* sigma */ 1.107500, /* size */ 7, /* weights */ 0.009198,0.070613,0.239883,0.360611,0.239883,0.070613,0.009198 },
    { /* t */ 0.800000, /* sigma */ 1.370000, /* size */ 7, /* weights */ 0.026722,0.101236,0.225122,0.293841,0.225122,0.101236,0.026722 },
    { /* t */ 0.900000, /* sigma */ 1.667500, /* size */ 9, /* weights */ 0.013552,0.047717,0.117259,0.201109,0.240727,0.201109,0.117259,0.047717,0.013552 },
    { /* t */ 1.000000, /* sigma */ 2.000000, /* size */ 9, /* weights */ 0.027631,0.066282,0.123832,0.180174,0.204164,0.180174,0.123832,0.066282,0.027631 }
};

unsigned int gaussianFilterKernelCount()
{
    return kGaussianFilterKernelCount;
}

float gaussianFilterStepForKernelIndex(int kernelIndex)
{
    return kGaussianFilterKernel[kernelIndex][0];
}

float gaussianFilterSigmaForKernelIndex(int kernelIndex)
{
    return kGaussianFilterKernel[kernelIndex][1];
}

unsigned int gaussianFilterSizeForKernelIndex(int kernelIndex)
{
    return (unsigned int)kGaussianFilterKernel[kernelIndex][2];
}

unsigned int gaussianFilterRadiusForKernelIndex(int kernelIndex)
{
    return (unsigned int)floor(gaussianFilterSizeForKernelIndex(kernelIndex)/2.0f);
}

float gaussianFilterWeightForIndexes(int kernelIndex, int weightIndex)
{
    return kGaussianFilterKernel[kernelIndex][3+weightIndex]; // FIXME improve this...wrong things can happen
}

#endif /* LMTCaptureVideoPreviewLayerGaussianFilterKernel_h */
