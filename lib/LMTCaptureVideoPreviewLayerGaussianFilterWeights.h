/*
 
 LMTCaptureVideoPreviewLayerGaussianFilterWeights.h
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

#ifndef LMTCaptureVideoPreviewLayerGaussianFilterWeights_h
#define LMTCaptureVideoPreviewLayerGaussianFilterWeights_h

/* 
 This values are generated from the matlab script:
 docs/matlab/LMTCaptureVideoPreviewLayer.m
 See project documentation for more details
 */

// Min sigma value for t = 0
static unsigned int const kGaussianFilterWeightsMinSigma = 0.5;

// Max sigma value for t = 1
static unsigned int const kGaussianFilterWeightsMaxSigma = 3.0;

// Number of generated filter kernels
static unsigned int const kGaussianFilterWeightsCount = 11;

static double const kGaussianFilterWeights[11][16] = {
    { /* t */ 0.000000, /* sigma */ 0.500000, /* size */ 3,  /* weights */ 0.106507,0.786986,0.106507 },
    { /* t */ 0.100000, /* sigma */ 0.525000, /* size */ 5,  /* weights */ 0.000532,0.122790,0.753356,0.122790,0.000532 },
    { /* t */ 0.200000, /* sigma */ 0.600000, /* size */ 5,  /* weights */ 0.002566,0.165525,0.663818,0.165525,0.002566 },
    { /* t */ 0.300000, /* sigma */ 0.725000, /* size */ 5,  /* weights */ 0.012250,0.212576,0.550347,0.212576,0.012250 },
    { /* t */ 0.400000, /* sigma */ 0.900000, /* size */ 5,  /* weights */ 0.037657,0.239936,0.444814,0.239936,0.037657 },
    { /* t */ 0.500000, /* sigma */ 1.125000, /* size */ 7,  /* weights */ 0.010143,0.073120,0.239196,0.355081,0.239196,0.073120,0.010143 },
    { /* t */ 0.600000, /* sigma */ 1.400000, /* size */ 7,  /* weights */ 0.028995,0.103818,0.223173,0.288026,0.223173,0.103818,0.028995 },
    { /* t */ 0.700000, /* sigma */ 1.725000, /* size */ 9,  /* weights */ 0.015852,0.051392,0.119063,0.197107,0.233173,0.197107,0.119063,0.051392,0.015852 },
    { /* t */ 0.800000, /* sigma */ 2.100000, /* size */ 11, /* weights */ 0.011253,0.031220,0.069041,0.121704,0.171011,0.191542,0.171011,0.121704,0.069041,0.031220,0.011253 },
    { /* t */ 0.900000, /* sigma */ 2.525000, /* size */ 13, /* weights */ 0.009478,0.022457,0.045486,0.078758,0.116570,0.147490,0.159523,0.147490,0.116570,0.078758,0.045486,0.022457,0.009478 },
    { /* t */ 1.000000, /* sigma */ 3.000000, /* size */ 13, /* weights */ 0.018544,0.034167,0.056332,0.083109,0.109719,0.129618,0.137023,0.129618,0.109719,0.083109,0.056332,0.034167,0.018544 }
};

#endif /* LMTCaptureVideoPreviewLayerGaussianFilterWeights_h */
