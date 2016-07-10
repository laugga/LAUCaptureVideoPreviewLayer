/*
 
 OGLUtilities.m
 Lightmate
 
 Copyright (cc) 2016 Luis Laugga.
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

#include "OGLUtilities.h"

// Checks current bound framebuffer status
bool checkFramebufferStatusComplete(void)
{
    GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    switch (framebufferStatus) {
        case GL_FRAMEBUFFER_COMPLETE:
            return true; // We can return true
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
            Logc("Framebuffer Status Error: Incomplete Attachment Point");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
            Logc("Framebuffer Status Error: Missing Attachment");
            break;
#if TARGET_OS_MAC && !TARGET_OS_IPHONE // NOT OPEN GL ES
        case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT:
            Logc("Framebuffer Status Error: Dimensions do not match");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT:
            Logc("Framebuffer Status Error: Formats");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER:
            Logc("Framebuffer Status Error: Draw Buffer");
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER:
            Logc("Framebuffer Status Error: Read Buffer");
            break;
#endif
        case GL_FRAMEBUFFER_UNSUPPORTED:
            Logc("Framebuffer Status Error: Unsupported Framebuffer Configuration");
            break;
        default:
            Logc("Framebuffer Status Error: Unkown Framebuffer Object Failure");
            break;
    }
    
    return false;
}
