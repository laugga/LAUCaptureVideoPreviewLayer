/*
 
 OGLShader.m
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

#include "OGLShader.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#pragma mark - 
#pragma mark Memory Management

Shader * allocShader(GLenum shaderType, const char * shaderSource)
{
    Shader * shader = (Shader *)calloc(sizeof(Shader), 1);
    shader->shaderType = shaderType;
	
    // Get the size of the source
	GLsizei sourceLength = (GLsizei)strlen(shaderSource);
	
	// Add 1 to the file size to include the null terminator for th string
    shader->byteSize = sourceLength + 1;
	
	// Alloc memory for the string
	shader->string = (GLchar*)malloc(shader->byteSize);
	
	// Copy the entire string
    strcpy(shader->string, shaderSource);
    
	// Insert null terminator
	shader->string[sourceLength] = 0;
	
	return shader;
}

void freeShader(Shader * shader)
{
    // Release dynamic memory allocated for string and the shader itself
	free(shader->string);
	free(shader);
}

#pragma mark -
#pragma mark Compilation

GLuint buildShader(const char * source, GLenum shaderType)
{
    GLint logLength, compileStatus;
    
    // Create shader
    GLuint shaderHandle = glCreateShader(shaderType);
    glShaderSource(shaderHandle, 1, &source, 0);   
    
    // Compile shader
    glCompileShader(shaderHandle);
    glGetShaderiv(shaderHandle, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0) 
	{
		GLchar *log = (GLchar*)malloc(logLength);
		glGetShaderInfoLog(shaderHandle, logLength, &logLength, log);
		Logc("Shader compile log:\n%s", log);
		free(log);
	}
    
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileStatus);
    if (compileStatus == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        Logc("Shader failed to compile:\n%s", messages);
        exit(1);
    }
    
    return shaderHandle;
}

GLuint buildProgram(const char * vertexShaderSource, const char * fragmentShaderSource)
{
    GLint logLength, linkStatus;
    
    // Compile fragment and vertex shader
    GLuint vertexShader = buildShader(vertexShaderSource, GL_VERTEX_SHADER);
    GLuint fragmentShader = buildShader(fragmentShaderSource, GL_FRAGMENT_SHADER);
    
    // Create program
    GLuint programHandle = glCreateProgram();
    
    // Attach compiled shaders
    glAttachShader(programHandle, vertexShader);
    glDeleteShader(vertexShader); // Flag for deletion
    glAttachShader(programHandle, fragmentShader);
    glDeleteShader(fragmentShader); // Flag for deletion
    
    // Link program
    glLinkProgram(programHandle);
    glGetProgramiv(programHandle, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar*)malloc(logLength);
		glGetProgramInfoLog(programHandle, logLength, &logLength, log);
		Logc("Program link log:\n%s", log);
		free(log);
	}
    
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        Logc("Failed to link program:\n%s", messages);
        exit(1);
    }
    
    return programHandle;
}

int validateProgram(GLuint programHandle)
{
    GLint logLength, validateStatus;
    
    // Validate program
    glValidateProgram(programHandle);
    glGetProgramiv(programHandle, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar*)malloc(logLength);
		glGetProgramInfoLog(programHandle, logLength, &logLength, log);
		Logc("Program validate log:\n%s", log);
		free(log);
	}
    
    glGetProgramiv(programHandle, GL_VALIDATE_STATUS, &validateStatus);
	if (validateStatus == GL_FALSE)
	{
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        Logc("Failed to validate program:\n%s", messages);
        exit(1);
	}
    
    return 0;
}

#pragma mark -
#pragma mark Loading

GLuint loadProgram(const char * vertexShaderSource, const char * fragmentShaderSource)
{
    // Program handle
    GLuint programHandle;
    
    // Load shaders
    Shader * vertexShader = allocShader(GL_VERTEX_SHADER, vertexShaderSource);
    Shader * fragmentShader = allocShader(GL_FRAGMENT_SHADER, fragmentShaderSource);
    
    // Create the GLSL program.
    programHandle = buildProgram(vertexShader->string, fragmentShader->string);
    
    // Unload shaders
    freeShader(vertexShader);
    freeShader(fragmentShader);
    
    return programHandle;
}

void unloadProgram(GLuint * programHandle)
{
    if (*programHandle) 
    {
        glDeleteProgram(*programHandle); // Delete program - shaders have been flagged after attaching and so will be deleted as well
        *programHandle = 0;
    }
}
