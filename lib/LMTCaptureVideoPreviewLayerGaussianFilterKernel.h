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

unsigned int gaussianFilterKernelCount()
{
    return kGaussianFilterKernelCount;
}

#pragma mark -
#pragma mark Weight for separable filtering

// For each step [0,1] there's a different kernel.
// These kernels are used to animate between filter intensity values
static float const kSepGaussianFilterKernel[11][50] = {
    { /* t */ 0.000000, /* sigma */ 0.250000, /* size */ 3, /* weights */ 0.000335,0.999330,0.000335 },
    { /* t */ 0.100000, /* sigma */ 1.697019, /* size */ 9, /* weights */ 0.014720,0.049627,0.118230,0.199036,0.236774,0.199036,0.118230,0.049627,0.014720 },
    { /* t */ 0.200000, /* sigma */ 3.108407, /* size */ 15, /* weights */ 0.010325,0.020232,0.035748,0.056954,0.081816,0.105976,0.123774,0.130348,0.123774,0.105976,0.081816,0.056954,0.035748,0.020232,0.010325 },
    { /* t */ 0.300000, /* sigma */ 4.449412, /* size */ 19, /* weights */ 0.011980,0.018404,0.026881,0.037328,0.049282,0.061860,0.073822,0.083759,0.090352,0.092663,0.090352,0.083759,0.073822,0.061860,0.049282,0.037328,0.026881,0.018404,0.011980 },
    { /* t */ 0.400000, /* sigma */ 5.687014, /* size */ 25, /* weights */ 0.007788,0.011113,0.015376,0.020626,0.026825,0.033827,0.041356,0.049022,0.056341,0.062780,0.067825,0.071045,0.072152,0.071045,0.067825,0.062780,0.056341,0.049022,0.041356,0.033827,0.026825,0.020626,0.015376,0.011113,0.007788 },
    { /* t */ 0.500000, /* sigma */ 6.790738, /* size */ 29, /* weights */ 0.007252,0.009718,0.012744,0.016353,0.020535,0.025232,0.030340,0.035698,0.041102,0.046308,0.051055,0.055081,0.058149,0.060072,0.060727,0.060072,0.058149,0.055081,0.051055,0.046308,0.041102,0.035698,0.030340,0.025232,0.020535,0.016353,0.012744,0.009718,0.007252 },
    { /* t */ 0.600000, /* sigma */ 7.733407, /* size */ 33, /* weights */ 0.006273,0.008129,0.010360,0.012983,0.016001,0.019394,0.023116,0.027096,0.031234,0.035407,0.039472,0.043274,0.046656,0.049468,0.051580,0.052890,0.053334,0.052890,0.051580,0.049468,0.046656,0.043274,0.039472,0.035407,0.031234,0.027096,0.023116,0.019394,0.016001,0.012983,0.010360,0.008129,0.006273 },
    { /* t */ 0.700000, /* sigma */ 8.491810, /* size */ 35, /* weights */ 0.006592,0.008287,0.010274,0.012562,0.015149,0.018016,0.021131,0.024443,0.027885,0.031373,0.034812,0.038095,0.041115,0.043762,0.045939,0.047559,0.048559,0.048897,0.048559,0.047559,0.045939,0.043762,0.041115,0.038095,0.034812,0.031373,0.027885,0.024443,0.021131,0.018016,0.015149,0.012562,0.010274,0.008287,0.006592 },
    { /* t */ 0.800000, /* sigma */ 9.047273, /* size */ 39, /* weights */ 0.005016,0.006289,0.007788,0.009527,0.011513,0.013744,0.016209,0.018883,0.021732,0.024706,0.027746,0.030783,0.033736,0.036525,0.039063,0.041271,0.043074,0.044410,0.045231,0.045508,0.045231,0.044410,0.043074,0.041271,0.039063,0.036525,0.033736,0.030783,0.027746,0.024706,0.021732,0.018883,0.016209,0.013744,0.011513,0.009527,0.007788,0.006289,0.005016 },
    { /* t */ 0.900000, /* sigma */ 9.386117, /* size */ 39, /* weights */ 0.005692,0.007023,0.008566,0.010330,0.012317,0.014521,0.016926,0.019506,0.022226,0.025039,0.027890,0.030715,0.033444,0.036005,0.038324,0.040333,0.041967,0.043175,0.043917,0.044167,0.043917,0.043175,0.041967,0.040333,0.038324,0.036005,0.033444,0.030715,0.027890,0.025039,0.022226,0.019506,0.016926,0.014521,0.012317,0.010330,0.008566,0.007023,0.005692 },
    { /* t */ 1.000000, /* sigma */ 9.500000, /* size */ 39, /* weights */ 0.005920,0.007267,0.008822,0.010592,0.012576,0.014768,0.017151,0.019699,0.022376,0.025137,0.027927,0.030686,0.033345,0.035835,0.038086,0.040034,0.041617,0.042786,0.043503,0.043744,0.043503,0.042786,0.041617,0.040034,0.038086,0.035835,0.033345,0.030686,0.027927,0.025137,0.022376,0.019699,0.017151,0.014768,0.012576,0.010592,0.008822,0.007267,0.005920 },
 
};

float sepGaussianFilterStepForKernelIndex(int kernelIndex)
{
    return kSepGaussianFilterKernel[kernelIndex][0];
}

float sepGaussianFilterSigmaForKernelIndex(int kernelIndex)
{
    return kSepGaussianFilterKernel[kernelIndex][1];
}

unsigned int sepGaussianFilterSizeForKernelIndex(int kernelIndex)
{
    return (unsigned int)kSepGaussianFilterKernel[kernelIndex][2];
}

unsigned int sepGaussianFilterRadiusForKernelIndex(int kernelIndex)
{
    return (unsigned int)floor(sepGaussianFilterSizeForKernelIndex(kernelIndex)/2.0f);
}

float sepGaussianFilterWeightForIndexes(int kernelIndex, int weightIndex)
{
    return kSepGaussianFilterKernel[kernelIndex][3+weightIndex]; // FIXME improve this...wrong things can happen
}

#pragma mark -
#pragma mark Fixed function sampling weights and offsets

// For each step [0,1] there's a different kernel.
// These kernels are used to animate between filter intensity values
static float const kFfsGaussianFilterKernel[11][50] = {
    { /* t */ 0.000000, /* sigma */ 0.250000, /* size */ 3, /* samples */ 1, /* offsets */ 0.000670, /* weights */ 0.500000 },
    { /* t */ 0.111111, /* sigma */ 1.277778, /* size */ 7, /* samples */ 2, /* offsets */ 0.595538,2.177820, /* weights */ 0.387887,0.112113 },
    { /* t */ 0.222222, /* sigma */ 2.305556, /* size */ 11, /* samples */ 3, /* offsets */ 0.645447,2.384542,4.300154, /* weights */ 0.248037,0.196167,0.055797 },
    { /* t */ 0.333333, /* sigma */ 3.333333, /* size */ 15, /* samples */ 4, /* offsets */ 0.656593,2.443986,4.400112,6.357783, /* weights */ 0.178527,0.184198,0.099491,0.037784 },
    { /* t */ 0.444444, /* sigma */ 4.361111, /* size */ 19, /* samples */ 5, /* offsets */ 0.660799,2.467186,4.441124,6.415382,8.390095, /* weights */ 0.138873,0.159170,0.110692,0.062548,0.028717 },
    { /* t */ 0.555556, /* sigma */ 5.388889, /* size */ 23, /* samples */ 6, /* offsets */ 0.662830,2.478491,4.461338,6.444275,8.427343,10.410580, /* weights */ 0.113481,0.136971,0.107856,0.074089,0.044396,0.023207 },
    { /* t */ 0.666667, /* sigma */ 6.416667, /* size */ 27, /* samples */ 7, /* offsets */ 0.663963,2.484825,4.472704,6.460615,8.448572,10.436589,12.424679, /* weights */ 0.095884,0.119155,0.100630,0.077162,0.053721,0.033958,0.019490 },
    { /* t */ 0.777778, /* sigma */ 7.444444, /* size */ 31, /* samples */ 8, /* offsets */ 0.664659,2.488724,4.479712,6.470712,8.461731,10.452775,12.443850,14.434961, /* weights */ 0.082989,0.105005,0.092598,0.075996,0.058046,0.041262,0.027297,0.016807 },
    { /* t */ 0.888889, /* sigma */ 8.472222, /* size */ 35, /* samples */ 9, /* offsets */ 0.665117,2.491294,4.484332,6.477376,8.470430,10.463494,12.456573,14.449668,16.442783, /* weights */ 0.073140,0.093651,0.084978,0.072943,0.059230,0.045497,0.033060,0.022725,0.014777 },
    { /* t */ 1.000000, /* sigma */ 9.500000, /* size */ 39, /* samples */ 10, /* offsets */ 0.665434,2.493075,4.487537,6.482002,8.476472,10.470947,12.465429,14.459920,16.454421,18.448932, /* weights */ 0.065375,0.084402,0.078120,0.069179,0.058613,0.047513,0.036851,0.027345,0.019414,0.013187 },
};

float ffsGaussianFilterStepForKernelIndex(int kernelIndex)
{
    return kFfsGaussianFilterKernel[kernelIndex][0];
}

float ffsGaussianFilterSigmaForKernelIndex(int kernelIndex)
{
    return kFfsGaussianFilterKernel[kernelIndex][1];
}

unsigned int ffsGaussianFilterSizeForKernelIndex(int kernelIndex)
{
    return (unsigned int)kFfsGaussianFilterKernel[kernelIndex][2];
}

unsigned int ffsGaussianFilterRadiusForKernelIndex(int kernelIndex)
{
    return (unsigned int)floor(ffsGaussianFilterSizeForKernelIndex(kernelIndex)/2.0f);
}

unsigned int ffsGaussianFilterSamplesForKernelIndex(int kernelIndex)
{
    return (unsigned int)kFfsGaussianFilterKernel[kernelIndex][3];
}

float gaussianFilterWeightForIndexes(int kernelIndex, int sampleIndex)
{
    unsigned int samples = ffsGaussianFilterSamplesForKernelIndex(kernelIndex);
    return kFfsGaussianFilterKernel[kernelIndex][4+samples+sampleIndex]; // FIXME improve this...wrong things can happen
}

float gaussianFilterOffsetForIndexes(int kernelIndex, int sampleIndex)
{
    return kFfsGaussianFilterKernel[kernelIndex][4+sampleIndex]; // FIXME improve this...wrong things can happen
}

#endif /* LMTCaptureVideoPreviewLayerGaussianFilterKernel_h */
