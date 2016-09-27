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
    { /* t */ 0.100000, /* sigma */ 0.277500, /* size */ 3, /* weights */ 0.001509,0.996981,0.001509 },
    { /* t */ 0.200000, /* sigma */ 0.360000, /* size */ 3, /* weights */ 0.020255,0.959491,0.020255 },
    { /* t */ 0.300000, /* sigma */ 0.497500, /* size */ 3, /* weights */ 0.104828,0.790345,0.104828 },
    { /* t */ 0.400000, /* sigma */ 0.690000, /* size */ 5, /* weights */ 0.008663,0.202271,0.578134,0.202271,0.008663 },
    { /* t */ 0.500000, /* sigma */ 0.937500, /* size */ 5, /* weights */ 0.043947,0.242175,0.427755,0.242175,0.043947 },
    { /* t */ 0.600000, /* sigma */ 1.240000, /* size */ 7, /* weights */ 0.017302,0.087946,0.233286,0.322934,0.233286,0.087946,0.017302 },
    { /* t */ 0.700000, /* sigma */ 1.597500, /* size */ 9, /* weights */ 0.010911,0.043003,0.114535,0.206161,0.250781,0.206161,0.114535,0.043003,0.010911 },
    { /* t */ 0.800000, /* sigma */ 2.010000, /* size */ 11, /* weights */ 0.009047,0.027557,0.065534,0.121676,0.176379,0.199616,0.176379,0.121676,0.065534,0.027557,0.009047 },
    { /* t */ 0.900000, /* sigma */ 2.477500, /* size */ 11, /* weights */ 0.021559,0.044878,0.079374,0.119279,0.152298,0.165224,0.152298,0.119279,0.079374,0.044878,0.021559 },
    { /* t */ 1.000000, /* sigma */ 3.000000, /* size */ 13, /* weights */ 0.018544,0.034167,0.056332,0.083109,0.109719,0.129618,0.137023,0.129618,0.109719,0.083109,0.056332,0.034167,0.018544 }
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
