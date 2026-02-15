@echo off

set GLSLC=..\..\..\Softwares\shaderc\build\glslc\Release\glslc.exe
set SHADERCROSS=..\..\..\..\Downloads\SDL_shadercross\build\Release\shadercross.exe
set SHADER_SRC=src\shaders\src
set SHADER_SPV_OUT=src\shaders\spv
set SHADER_MSL_OUT=src\shaders\msl
set SHADER_DXIL_OUT=src\shaders\dxil
set SHADER_JSON_OUT=src\shaders\json
set SHADER_NAME=raymarch

if not exist "%GLSLC%" (
    echo ERROR: glslc not found at %GLSLC%
    exit /b 1
)
if not exist "%SHADERCROSS%" (
    echo ERROR: shadercross not found at %SHADERCROSS%
    exit /b 1
)
if not exist "%SHADER_SRC%" (
    echo ERROR: shader source dir not found at %SHADER_SRC%
    exit /b 1
)

%GLSLC% -fshader-stage=vertex %SHADER_SRC%\%SHADER_NAME%.vert.glsl -o %SHADER_SPV_OUT%\%SHADER_NAME%.vert.spv
if %errorlevel% neq 0 ( echo ERROR: glslc vert failed & exit /b %errorlevel% )

%GLSLC% -fshader-stage=fragment %SHADER_SRC%\%SHADER_NAME%.frag.glsl -o %SHADER_SPV_OUT%\%SHADER_NAME%.frag.spv
if %errorlevel% neq 0 ( echo ERROR: glslc frag failed & exit /b %errorlevel% )

%SHADERCROSS% %SHADER_SPV_OUT%\%SHADER_NAME%.vert.spv --source SPIRV --dest MSL --stage vertex --entrypoint main -o %SHADER_MSL_OUT%\%SHADER_NAME%.vert.msl
if %errorlevel% neq 0 ( echo ERROR: shadercross vert MSL failed & exit /b %errorlevel% )

%SHADERCROSS% %SHADER_SPV_OUT%\%SHADER_NAME%.frag.spv --source SPIRV --dest MSL --stage fragment --entrypoint main -o %SHADER_MSL_OUT%\%SHADER_NAME%.frag.msl
if %errorlevel% neq 0 ( echo ERROR: shadercross frag MSL failed & exit /b %errorlevel% )

%SHADERCROSS% %SHADER_SPV_OUT%\%SHADER_NAME%.vert.spv --source SPIRV --dest DXIL --stage vertex --entrypoint main -o %SHADER_DXIL_OUT%\%SHADER_NAME%.vert.dxil
if %errorlevel% neq 0 ( echo ERROR: shadercross vert DXIL failed & exit /b %errorlevel% )

%SHADERCROSS% %SHADER_SPV_OUT%\%SHADER_NAME%.frag.spv --source SPIRV --dest DXIL --stage fragment --entrypoint main -o %SHADER_DXIL_OUT%\%SHADER_NAME%.frag.dxil
if %errorlevel% neq 0 ( echo ERROR: shadercross frag DXIL failed & exit /b %errorlevel% )

%SHADERCROSS% %SHADER_SPV_OUT%\%SHADER_NAME%.vert.spv --source SPIRV --dest JSON --stage vertex --entrypoint main -o %SHADER_JSON_OUT%\%SHADER_NAME%.vert.json
if %errorlevel% neq 0 ( echo ERROR: shadercross vert JSON failed & exit /b %errorlevel% )

%SHADERCROSS% %SHADER_SPV_OUT%\%SHADER_NAME%.frag.spv --source SPIRV --dest JSON --stage fragment --entrypoint main -o %SHADER_JSON_OUT%\%SHADER_NAME%.frag.json
if %errorlevel% neq 0 ( echo ERROR: shadercross frag JSON failed & exit /b %errorlevel% )
