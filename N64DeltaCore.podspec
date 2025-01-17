Pod::Spec.new do |spec|
  spec.name         = "N64DeltaCore"
  spec.version      = "0.1"
  spec.summary      = "Nintendo 64 plug-in for Delta emulator."
  spec.description  = "iOS framework that wraps Mupen64Plus to allow playing Nintendo 64 games with Delta emulator."
  spec.homepage     = "https://github.com/rileytestut/N64DeltaCore"
  spec.platform     = :ios, "12.0"
  spec.source       = { :git => "https://github.com/rileytestut/N64DeltaCore.git" }

  spec.author             = { "Riley Testut" => "riley@rileytestut.com" }
  spec.social_media_url   = "https://twitter.com/rileytestut"
  
  spec.source_files  = "N64DeltaCore/**/*.{h,m,mm,cpp,swift}", "N64DeltaCore/N64DeltaCore.h", "Mupen64Plus/mupen64plus-core/src/backends/api/video_capture_backend.c", "Mupen64Plus/mupen64plus-core/src/device/dd/dd_controller.c", "Mupen64Plus/mupen64plus-core/src/device/controllers/paks/biopak.c", "Mupen64Plus/mupen64plus-core/src/backends/dummy_video_capture.c", "Mupen64Plus/mupen64plus-core/src/api/**/*.{h,hpp}", "Mupen64Plus/mupen64plus-core/src/backends/**/*.{h,hpp}", "Mupen64Plus/mupen64plus-core/src/device/**/*.{h,hpp}", "Mupen64Plus/mupen64plus-core/src/main/**/*.{h,hpp}", "Mupen64Plus/mupen64plus-core/src/osal/**/*.{h,hpp}", "Mupen64Plus/mupen64plus-core/src/osd/**/*.{h,hpp}", "Mupen64Plus/mupen64plus-core/src/plugin/**/*.{h,hpp}", "Mupen64Plus/mupen64plus-core/subprojects/**/*.{h,hpp}", "libMupen64Plus/SDL/*.{h,hpp}"
  spec.exclude_files = "Mupen64Plus/mupen64plus-core/src/api/config.h"
  spec.public_header_files = "N64DeltaCore/Types/N64Types.h", "N64DeltaCore/Bridge/N64EmulatorBridge.h", "N64DeltaCore/N64DeltaCore.h"
  spec.header_mappings_dir = ""
  spec.resource_bundles = {
    "Mupen64Plus" => ["N64DeltaCore/**/*.deltamapping", "N64DeltaCore/**/*.deltaskin", "Mupen64Plus/**/*.ini"]
  }
  
  spec.xcconfig = {
    "HEADER_SEARCH_PATHS" => '"${PODS_CONFIGURATION_BUILD_DIR}" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/mupen64plus-core/subprojects/**" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/libMupen64Plus/SDL"',
    
    "USER_HEADER_SEARCH_PATHS" => '"${PODS_CONFIGURATION_BUILD_DIR}/DeltaCore/Swift Compatibility Header" "${PODS_ROOT}/Headers/Public/DeltaCore" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/mupen64plus-core/src" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/mupen64plus-core/src/api" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/mupen64plus-core/src/osd" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src"',
    
    "CLANG_ENABLE_MODULES" => "NO",
    "GCC_PREPROCESSOR_DEFINITIONS" => "STATIC_LIBRARY=1"
  }
  
  spec.script_phase = {
    :name => 'Get GlideN64 Revision.h',
    :script => '"${PODS_TARGET_SRCROOT}/Mupen64Plus/GLideN64/src/getRevision.sh"',
    :execution_position => :before_compile
  }
  
  spec.dependency 'DeltaCore'
  
  spec.subspec 'RSP' do |rsp|
    rsp.source_files  = "Mupen64Plus/mupen64plus-rsp-hle/src/*.{h,c}", "N64DeltaCore-RSP/plugin_delta.c"
    rsp.exclude_files = "Mupen64Plus/mupen64plus-rsp-hle/src/osal_dynamiclib_*.c", "Mupen64Plus/mupen64plus-rsp-hle/src/plugin.c", "Mupen64Plus/mupen64plus-rsp-hle/src/memory.h"
    rsp.private_header_files = "**/*"
    rsp.header_mappings_dir = "Mupen64Plus"
    
    rsp.xcconfig = {
      "OTHER_CFLAGS" => "-fno-strict-aliasing -DGCC -pthread -fPIC -D__unix__ -ffast-math"
    }
  end
  
  spec.subspec 'Video' do |video|
    video.source_files  = "Mupen64Plus/GLideN64/src/**/*.{h,hpp}", "Mupen64Plus/libpng/**/*.{h,hpp}", "N64DeltaCore-Video/plugin_delta.cpp", "**/3DMath.cpp", "**/ClipPolygon.cpp", "**/ColorBufferReader.cpp", "**/ColorBufferToRDRAM.cpp", "**/Combiner.cpp", "**/CombinerKey.cpp", "**/CombinerProgram.cpp", "**/CommonAPIImpl_common.cpp", "**/CommonAPIImpl_mupenplus.cpp", "**/CommonPluginAPI.cpp", "**/Config_mupenplus.cpp", "**/Config.cpp", "**/Context.cpp", "**/convert.cpp", "**/CRC_OPT.cpp", "**/DebugDump.cpp", "**/Debugger.cpp", "**/DepthBuffer.cpp", "**/DepthBufferRender.cpp", "**/DepthBufferToRDRAM.cpp", "**/DisplayLoadProgress.cpp", "**/DisplayWindow.cpp", "**/F3D.cpp", "**/F3DAM.cpp", "**/F3DBETA.cpp", "**/F3DDKR.cpp", "**/F3DEX.cpp", "**/F3DEX2.cpp", "**/F3DEX2ACCLAIM.cpp", "**/F3DEX2CBFD.cpp", "**/F3DFLX2.cpp", "**/F3DGOLDEN.cpp", "**/F3DPD.cpp", "**/F3DSETA.cpp", "**/F3DTEXA.cpp", "**/F3DZEX2.cpp", "**/F5Indi_Naboo.cpp", "**/F5Rogue.cpp", "**/FrameBuffer.cpp", "**/FrameBufferInfo.cpp", "**/GBI.cpp", "**/gDP.cpp", "**/GLFunctions.cpp", "**/GLideN64.cpp", "**/glsl_CombinerInputs.cpp", "**/glsl_CombinerProgramBuilder.cpp", "**/glsl_CombinerProgramImpl.cpp", "**/glsl_CombinerProgramUniformFactory.cpp", "**/glsl_FXAA.cpp", "**/glsl_ShaderStorage.cpp", "**/glsl_SpecialShadersFactory.cpp", "**/glsl_Utils.cpp", "**/GraphicsDrawer.cpp", "**/gSP.cpp", "**/Keys.cpp", "**/L3D.cpp", "**/L3DEX.cpp", "**/L3DEX2.cpp", "**/Log_ios.mm", "**/MemoryStatus_mupenplus.cpp", "**/mupen64plus_DisplayWindow.cpp", "**/MupenPlusAPIImpl.cpp", "**/MupenPlusPluginAPI.cpp", "**/N64.cpp", "**/NoiseTexture.cpp", "**/ObjectHandle.cpp", "**/opengl_Attributes.cpp", "**/opengl_BufferedDrawer.cpp", "**/opengl_BufferManipulationObjectFactory.cpp", "**/opengl_CachedFunctions.cpp", "**/opengl_ColorBufferReaderWithBufferStorage.cpp", "**/opengl_ColorBufferReaderWithPixelBuffer.cpp", "**/opengl_ColorBufferReaderWithReadPixels.cpp", "**/opengl_ContextImpl.cpp", "**/opengl_GLInfo.cpp", "**/opengl_Parameters.cpp", "**/opengl_TextureManipulationObjectFactory.cpp", "**/opengl_UnbufferedDrawer.cpp", "**/opengl_Utils.cpp", "**/osal_files_ios.mm", "**/PaletteTexture.cpp", "**/Performance.cpp", "**/png.c", "**/pngerror.c", "**/pngget.c", "**/pngmem.c", "**/pngpread.c", "**/pngread.c", "**/pngrio.c", "**/pngrtran.c", "**/pngrutil.c", "**/pngset.c", "**/pngtest.c", "**/pngtrans.c", "**/pngwio.c", "**/pngwrite.c", "**/pngwtran.c", "**/pngwutil.c", "**/PostProcessor.cpp", "**/RDP.cpp", "**/RDRAMtoColorBuffer.cpp", "**/RSP_LoadMatrix.cpp", "**/RSP.cpp", "**/S2DEX.cpp", "**/S2DEX2.cpp", "**/SoftwareRender.cpp", "**/T3DUX.cpp", "**/TexrectDrawer.cpp", "**/TextDrawerStub.cpp", "**/TextureFilterHandler.cpp", "**/TextureFilters_2xsai.cpp", "**/TextureFilters_hq2x.cpp", "**/TextureFilters_hq4x.cpp", "**/TextureFilters_xbrz.cpp", "**/TextureFilters.cpp", "**/Textures.cpp", "**/Turbo3D.cpp", "**/TxCache.cpp", "**/TxDbg_ios.mm", "**/TxFilter.cpp", "**/TxFilterExport.cpp", "**/TxHiResCache.cpp", "**/TxImage.cpp", "**/TxQuantize.cpp", "**/TxReSample.cpp", "**/TxTexCache.cpp", "**/TxUtil.cpp", "**/txWidestringWrapper.cpp", "**/VI.cpp", "**/xxhash.c", "**/ZlutTexture.cpp", "**/ZSort.cpp", "**/ZSortBOSS.cpp"
    video.exclude_files = "Mupen64Plus/GLideN64/src/windows/**/*", "Mupen64Plus/GLideN64/src/inc/config.h", "Mupen64Plus/GLideN64/src/CommonPluginAPI.cpp", "Mupen64Plus/GLideN64/src/MupenPlusPluginAPI.cpp", "Mupen64Plus/GLideN64/src/mupenplus/MupenPlusAPIImpl.cpp", "Mupen64Plus/GLideN64/src/mupenplus/CommonAPIImpl_mupenplus.cpp", "Mupen64Plus/GLideN64/src/mupenplus/Config_mupenplus.cpp"
    video.private_header_files = "**/*"
    video.header_mappings_dir = ""
    
    video.xcconfig = {
      "HEADER_SEARCH_PATHS" => '"$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src/inc" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src/osal" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/libpng"',
      "USER_HEADER_SEARCH_PATHS" => '"$(PODS_ROOT)/Headers/Private/N64DeltaCore/N64DeltaCore-Video/**" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/mupen64plus-core/src" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src/GLideNHQ/inc" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src/osal" "$(PODS_ROOT)/Headers/Private/N64DeltaCore/Mupen64Plus/GLideN64/src/GLideNHQ" "$(PODS_ROOT)/Headers/Public/N64DeltaCore/N64DeltaCore/**"',
      "OTHER_CFLAGS" => "-fno-strict-aliasing -DGCC -pthread -fPIC -D__unix__ -ffast-math -D__VEC4_OPT -fvisibility=hidden",
      "OTHER_LDFLAGS" => "-Wl,-exported_symbol,_Video_PluginStartup,-exported_symbol,_Video_PluginShutdown,-exported_symbol,_Video_PluginGetVersion,-exported_symbol,_Video_RomOpen,-exported_symbol,_Video_RomClosed,-exported_symbol,_ConfigGetSharedDataFilepath,-exported_symbol,_ConfigGetUserConfigPath,-exported_symbol,_ConfigGetUserCachePath,-exported_symbol,_ConfigGetUserDataPath,-exported_symbol,_ConfigOpenSection,-exported_symbol,_ConfigDeleteSection,-exported_symbol,_ConfigSaveSection,-exported_symbol,_ConfigSaveFile,-exported_symbol,_ConfigSetDefaultInt,-exported_symbol,_ConfigSetDefaultFloat,-exported_symbol,_ConfigSetDefaultBool,-exported_symbol,_ConfigSetDefaultString,-exported_symbol,_ConfigGetParamInt,-exported_symbol,_ConfigGetParamFloat,-exported_symbol,_ConfigGetParamBool,-exported_symbol,_ConfigGetParamString,-exported_symbol,_ConfigExternalGetParameter,-exported_symbol,_ConfigExternalOpen,-exported_symbol,_ConfigExternalClose,-exported_symbol,_VidExt_Init,-exported_symbol,_VidExt_Quit,-exported_symbol,_VidExt_ListFullscreenModes,-exported_symbol,_VidExt_SetVideoMode,-exported_symbol,_VidExt_SetCaption,-exported_symbol,_VidExt_ToggleFullScreen,-exported_symbol,_VidExt_ResizeWindow,-exported_symbol,_VidExt_GL_GetProcAddress,-exported_symbol,_VidExt_GL_SetAttribute,-exported_symbol,_VidExt_GL_GetAttribute,-exported_symbol,_VidExt_GL_SwapBuffers,-exported_symbol,_ChangeWindow,-exported_symbol,_InitiateGFX,-exported_symbol,_MoveScreen,-exported_symbol,_ProcessDList,-exported_symbol,_ProcessRDPList,-exported_symbol,_ShowCFB,-exported_symbol,_UpdateScreen,-exported_symbol,_ViStatusChanged,-exported_symbol,_ViWidthChanged,-exported_symbol,_ReadScreen2,-exported_symbol,_SetRenderingCallback,-exported_symbol,_FBRead,-exported_symbol,_FBWrite,-exported_symbol,_FBGetFrameBufferInfo,-exported_symbol,_ResizeVideoOutput,-exported_symbol,_RSP_PluginStartup,-exported_symbol,_RSP_PluginShutdown,-exported_symbol,_RSP_PluginGetVersion,-exported_symbol,_DoRspCycles,-exported_symbol,_InitiateRSP,-exported_symbol,_RSP_RomClosed,-exported_symbol,_CoreGetAPIVersions,-exported_symbol,_ConfigGetParameter,-exported_symbol,_ConfigSetParameter,-exported_symbol,_CoreDoCommand",
      "GCC_PREPROCESSOR_DEFINITIONS" => "MUPENPLUSAPI TXFILTER_LIB OS_IOS GLESX GL_ERROR_DEBUG GL_DEBUG GLESX PNG_ARM_NEON_OPT=0",
      "GCC_OPTIMIZATION_LEVEL" => "3",
      "USE_HEADERMAP" => "NO"
    }
  end
  
end
