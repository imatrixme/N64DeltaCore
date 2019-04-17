//
//  N64EmulatorBridge.m
//  N64DeltaCore
//
//  Created by Riley Testut on 3/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "N64EmulatorBridge.h"
#import <N64DeltaCore/N64DeltaCore-Swift.h>

#define M64P_CORE_PROTOTYPES

#include "api/config.h"
#include "api/m64p_common.h"
#include "api/m64p_config.h"
#include "api/m64p_frontend.h"
#include "api/m64p_vidext.h"
#include "api/callbacks.h"
#include "main/rom.h"
#include "main/savestates.h"
#include "main/cheat.h"
#include "osal/dynamiclib.h"
#include "main/version.h"
#include "main/main.h"
#include "osd.h"

#include "plugin/plugin.h"

#import <dlfcn.h>
#import <mach-o/ldsyms.h>

@import Darwin;

@interface N64EmulatorBridge ()
{
}

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;

@property (nonatomic, readonly) NSURL *n64DirectoryURL;
@property (nonatomic, readonly) NSURL *gameSaveDirectoryURL;
@property (nonatomic, readonly) NSURL *configDirectoryURL;

@property (nonatomic, assign) BOOL isNTSC;
@property (nonatomic, assign) double sampleRate;

@property (nonatomic, strong) dispatch_semaphore_t beginFrameSemaphore;
@property (nonatomic, strong) dispatch_semaphore_t endFrameSemaphore;
@property (nonatomic, strong) dispatch_semaphore_t stopEmulationSemaphore;

@property (nonatomic) BOOL didLoadPlugins;
@property (nonatomic, assign, getter=isRunning) BOOL running;

@property (nonatomic, strong, readwrite) AVAudioFormat *preferredAudioFormat;
@property (nonatomic, readwrite) CGSize preferredVideoDimensions;

@end

@implementation N64EmulatorBridge
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

static void MupenDebugCallback(void *context, int level, const char *message)
{
    NSLog(@"Mupen (%d): %s", level, message);
}

static void MupenStateCallback(void *context, m64p_core_param paramType, int newValue)
{
    NSLog(@"Mupen: param %d -> %d", paramType, newValue);
}

static void *dlopen_N64DeltaCore()
{
    Dl_info info;
    
    dladdr(dlopen_N64DeltaCore, &info);
    
    return dlopen(info.dli_fname, RTLD_LAZY | RTLD_GLOBAL);
}

static void MupenGetKeys(int Control, BUTTONS *Keys)
{
}

static void MupenInitiateControllers (CONTROL_INFO ControlInfo)
{
}

static void MupenControllerCommand(int Control, unsigned char *Command)
{
}

static AUDIO_INFO AudioInfo;

static void MupenAudioSampleRateChanged(int SystemType)
{
    double previousSampleRate = N64EmulatorBridge.sharedBridge.preferredAudioFormat.sampleRate;
    double sampleRate = 0.0;
    
    switch (SystemType)
    {
        default:
        case SYSTEM_NTSC:
            sampleRate = 48681812 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
        case SYSTEM_PAL:
            sampleRate = 49656530 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
    }
    
    NSLog(@"Mupen rate changed %f -> %f\n", previousSampleRate, sampleRate);
    
    N64EmulatorBridge.sharedBridge.preferredAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:sampleRate channels:2 interleaved:YES];
}

static void MupenAudioLenChanged()
{
    int LenReg = *AudioInfo.AI_LEN_REG;
    uint8_t *ptr = (uint8_t*)(AudioInfo.RDRAM + (*AudioInfo.AI_DRAM_ADDR_REG & 0xFFFFFF));
    
    // Swap channels
    for (uint32_t i = 0; i < LenReg; i += 4)
    {
        ptr[i] ^= ptr[i + 2];
        ptr[i + 2] ^= ptr[i];
        ptr[i] ^= ptr[i + 2];
        ptr[i + 1] ^= ptr[i + 3];
        ptr[i + 3] ^= ptr[i + 1];
        ptr[i + 1] ^= ptr[i + 3];
    }
    
    [N64EmulatorBridge.sharedBridge.audioRenderer.audioBuffer writeBuffer:ptr size:LenReg];
}

static void SetIsNTSC()
{
    switch (ROM_HEADER.Country_code & 0xFF)
    {
        case 0x44:
        case 0x46:
        case 0x49:
        case 0x50:
        case 0x53:
        case 0x55:
        case 0x58:
        case 0x59:
            N64EmulatorBridge.sharedBridge.isNTSC = NO;
            break;
            
        case 0x37:
        case 0x41:
        case 0x45:
        case 0x4a:
            N64EmulatorBridge.sharedBridge.isNTSC = YES;
            break;
    }
}

static int MupenOpenAudio(AUDIO_INFO info)
{
    AudioInfo = info;
    
    SetIsNTSC();
    
    return M64ERR_SUCCESS;
}

static void MupenSetAudioSpeed(int percent)
{
}

+ (instancetype)sharedBridge
{
    static N64EmulatorBridge *_emulatorBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _emulatorBridge = [[self alloc] init];
    });
    
    return _emulatorBridge;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _beginFrameSemaphore = dispatch_semaphore_create(0);
        _endFrameSemaphore = dispatch_semaphore_create(0);
        _stopEmulationSemaphore = dispatch_semaphore_create(0);
        
        _preferredAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:44100 channels:2 interleaved:YES];
        _preferredVideoDimensions = CGSizeMake(640, 480);
    }
    
    return self;
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
    
    /* Copy .ini files */
    NSArray<NSString *> *iniFiles = @[@"GLideN64", @"GLideN64.custom", @"mupen64plus"];
    for (NSString *filename in iniFiles)
    {
        NSURL *sourceURL = [[NSBundle bundleForClass:self.class] URLForResource:filename withExtension:@"ini"];
        NSURL *destinationURL = [[self.n64DirectoryURL URLByAppendingPathComponent:filename] URLByAppendingPathExtension:@"ini"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path isDirectory:nil])
        {
            continue;
        }
        
        NSError *error = nil;
        if (![[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:destinationURL error:&error])
        {
            NSLog(@"Error copying %@. %@", filename, error);
        }
    }
    
    /* Prepare Emulation */
    CoreStartup(FRONTEND_API_VERSION, self.configDirectoryURL.fileSystemRepresentation, self.n64DirectoryURL.fileSystemRepresentation, (__bridge void *)self, MupenDebugCallback, (__bridge void *)self, MupenStateCallback);
    
    /* Configure Core */
    m64p_handle config;
    ConfigOpenSection("Core", &config);
    
    ConfigSetParameter(config, "SaveSRAMPath", M64TYPE_STRING, self.gameSaveDirectoryURL.fileSystemRepresentation);
    ConfigSetParameter(config, "SharedDataPath", M64TYPE_STRING, self.n64DirectoryURL.fileSystemRepresentation);
    
    // Pure Interpreter = 0, Cached Interpreter = 1, Dynamic Recompiler = 2
    int emulationMode = 1;
    ConfigSetParameter(config, "R4300Emulator", M64TYPE_INT, &emulationMode);
    
    ConfigSaveSection("Core");
    
    
    /* Configure Video */
    m64p_handle video;
    ConfigOpenSection("Video-General", &video);
    
    int useFullscreen = 1;
    ConfigSetParameter(video, "Fullscreen", M64TYPE_BOOL, &useFullscreen);
    
    int screenWidth = 640;
    ConfigSetParameter(video, "ScreenWidth", M64TYPE_INT, &screenWidth);
    
    int screenHeight = 480;
    ConfigSetParameter(video, "ScreenHeight", M64TYPE_INT, &screenHeight);
    
    ConfigSaveSection("Video-General");
    
    
    /* Configure GLideN64 */
    m64p_handle gliden64;
    ConfigOpenSection("Video-GLideN64", &gliden64);
    
    // 0 = stretch, 1 = 4:3, 2 = 16:9, 3 = adjust
    int aspectRatio = 1;
    ConfigSetParameter(gliden64, "AspectRatio", M64TYPE_INT, &aspectRatio);
    
    int enablePerPixelLighting = 1;
    ConfigSetParameter(gliden64, "EnableHWLighting", M64TYPE_BOOL, &enablePerPixelLighting);
    
    int osd = 0;
    ConfigSetParameter(gliden64, "OnScreenDisplay", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowFPS", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowVIS", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowPercent", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowInternalResolution", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowRenderingResolution", M64TYPE_BOOL, &osd);
    
    ConfigSaveSection("Video-GLideN64");
    
    NSData *romData = [NSData dataWithContentsOfURL:gameURL options:NSDataReadingMappedAlways error:nil];
    if (romData.length == 0)
    {
        NSLog(@"Error loading ROM at path: %@\n File does not exist.", gameURL);
        return;
    }
    
    m64p_error openStatus = CoreDoCommand(M64CMD_ROM_OPEN, (int)[romData length], (void *)[romData bytes]);
    if (openStatus != M64ERR_SUCCESS)
    {
        NSLog(@"Error loading ROM at path: %@\n Error code was: %i", gameURL, openStatus);
        return;
    }
    
    
    /* Prepare Audio */
    audio.aiDacrateChanged = MupenAudioSampleRateChanged;
    audio.aiLenChanged = MupenAudioLenChanged;
    audio.initiateAudio = MupenOpenAudio;
    audio.setSpeedFactor = MupenSetAudioSpeed;
    plugin_start(M64PLUGIN_AUDIO);
    
    /* Prepare Input */
    input.getKeys = MupenGetKeys;
    input.initiateControllers = MupenInitiateControllers;
    input.controllerCommand = MupenControllerCommand;
    plugin_start(M64PLUGIN_INPUT);
    
    if (![self didLoadPlugins])
    {
        /* Prepare Plugins */
        NSAssert([self loadPlugin:@"N64DeltaCore_Video" type:M64PLUGIN_GFX], @"Failed to load video plugin.");
        NSAssert([self loadPlugin:@"N64DeltaCore_RSP" type:M64PLUGIN_RSP], @"Failed to load RSP plugin.");
        
        self.didLoadPlugins = YES;
    }
    
    self.running = YES;
    
    [NSThread detachNewThreadSelector:@selector(startEmulationLoop) toTarget:self withObject:nil];
    
    dispatch_semaphore_wait(self.endFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)startEmulationLoop
{
    @autoreleasepool
    {
        [self.videoRenderer prepare];
        
        CoreDoCommand(M64CMD_EXECUTE, 0, NULL);
        
        dispatch_semaphore_signal(self.stopEmulationSemaphore);
    }
}

- (void)stop
{
    CoreDoCommand(M64CMD_STOP, 0, NULL);
    
    dispatch_semaphore_signal(self.beginFrameSemaphore);
    dispatch_semaphore_wait(self.stopEmulationSemaphore, DISPATCH_TIME_FOREVER);
    
    CoreDoCommand(M64CMD_ROM_CLOSE, 0, NULL);
    
    self.running = NO;
}

- (void)pause
{
    self.running = NO;
}

- (void)resume
{
    self.running = YES;
}

#pragma mark - Game Loop -

- (void)runFrame
{
    dispatch_semaphore_signal(self.beginFrameSemaphore);
    
    dispatch_semaphore_wait(self.endFrameSemaphore, DISPATCH_TIME_FOREVER);
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)input
{
}

- (void)deactivateInput:(NSInteger)input
{
}

- (void)resetInputs
{
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)url
{
}

- (void)loadSaveStateFromURL:(NSURL *)url
{
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)url
{
}

- (void)loadGameSaveFromURL:(NSURL *)url
{
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)code type:(NSString *)type
{
    return YES;
}

- (void)resetCheats
{
}

- (void)updateCheats
{
}

#pragma mark - Helper Methods -

- (void)processFrame
{
    [self.videoRenderer processFrame];
}

- (void)videoInterrupt
{
    dispatch_semaphore_signal(self.endFrameSemaphore);
    
    dispatch_semaphore_wait(self.beginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (BOOL)loadPlugin:(NSString *)pluginName type:(m64p_plugin_type)type
{
    m64p_dynlib_handle n64DeltaCoreHandle = dlopen_N64DeltaCore();
    
    NSString *frameworkPath = [NSString stringWithFormat:@"%@.framework/%@", pluginName, pluginName];
    NSString *pluginPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:frameworkPath];
    
    m64p_dynlib_handle pluginHandle = dlopen([pluginPath fileSystemRepresentation], RTLD_LAZY | RTLD_LOCAL);
    
    ptr_PluginStartup pluginStart = dlsym(pluginHandle, "PluginStartup");
    m64p_error error = pluginStart(n64DeltaCoreHandle, (__bridge void *)self, MupenDebugCallback);
    if (error != M64ERR_SUCCESS)
    {
        NSLog(@"Error code %@ loading plugin of type %@, name: %@", @(error), @(type), pluginName);
        return NO;
    }
    
    error = CoreAttachPlugin(type, pluginHandle);
    if (error != M64ERR_SUCCESS)
    {
        NSLog(@"Error code %@ attaching plugin of type %@, name: %@", @(error), @(type), pluginName);
        return NO;
    }
    
    return YES;
}

#pragma mark - Getters/Setters -

- (NSTimeInterval)frameDuration
{
    return [self isNTSC] ? (1.0 / 60.0) : (1.0 / 50.0);
}

- (NSURL *)n64DirectoryURL
{
    NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *n64DirectoryURL = [temporaryDirectoryURL URLByAppendingPathComponent:@"com.rileytestut.Delta.N64DeltaCore" isDirectory:YES];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:n64DirectoryURL withIntermediateDirectories:YES attributes:nil error:nil])
    {
        NSLog(@"Unable to create N64 Directory. %@", error);
    }
    
    return n64DirectoryURL;
}

- (NSURL *)gameSaveDirectoryURL
{
    NSURL *gameSaveDirectoryURL = [self.n64DirectoryURL URLByAppendingPathComponent:@"Saves" isDirectory:YES];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:gameSaveDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil])
    {
        NSLog(@"Unable to create Game Save Directory. %@", error);
    }
    
    return gameSaveDirectoryURL;
}

- (NSURL *)configDirectoryURL
{
    NSURL *configDirectoryURL = [self.n64DirectoryURL URLByAppendingPathComponent:@"Config" isDirectory:YES];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:configDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil])
    {
        NSLog(@"Unable to create Config Directory. %@", error);
    }
    
    return configDirectoryURL;
}

@end

#pragma mark - Mupen64Plus Callbacks -

EXPORT m64p_error CALL VidExt_Init(void)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_Quit(void)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ListFullscreenModes(m64p_2d_size *SizeArray, int *NumSizes)
{
    *NumSizes = 0;
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_SetVideoMode(int Width, int Height, int BitsPerPixel, m64p_video_mode ScreenMode, m64p_video_flags Flags)
{
    N64EmulatorBridge.sharedBridge.preferredVideoDimensions = CGSizeMake(Width, Height);
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_SetCaption(const char *Title)
{
    NSLog(@"Mupen caption: %s", Title);
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ToggleFullScreen(void)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_function CALL VidExt_GL_GetProcAddress(const char* Proc)
{
    return dlsym(RTLD_NEXT, Proc);
}

EXPORT m64p_error CALL VidExt_GL_SetAttribute(m64p_GLattr Attr, int Value)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_GL_GetAttribute(m64p_GLattr Attr, int *pValue)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_GL_SwapBuffers(void)
{
    [N64EmulatorBridge.sharedBridge.videoRenderer processFrame];
    
    return M64ERR_SUCCESS;
}

m64p_error OverrideVideoFunctions(m64p_video_extension_functions *VideoFunctionStruct)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ResizeWindow(int width, int height)
{
    return M64ERR_SUCCESS;
}

int VidExt_InFullscreenMode(void)
{
    return 1;
}

int VidExt_VideoRunning(void)
{
    return N64EmulatorBridge.sharedBridge.isRunning;
}

void new_vi(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;
    
    if (g_gs_vi_counter < 60)
    {
        if (g_gs_vi_counter == 0)
        {
            cheat_apply_cheats(&g_cheat_ctx, r4300, ENTRY_BOOT);
        }
        
        g_gs_vi_counter = 60;
    }
    else
    {
        cheat_apply_cheats(&g_cheat_ctx, r4300, ENTRY_VI);
    }
    
    [N64EmulatorBridge.sharedBridge videoInterrupt];
}

void ScreenshotRomOpen(void)
{
}

void TakeScreenshot(int iFrameNumber)
{
}

void osd_message_set_corner(osd_message_t *, enum osd_corner);

osd_message_t * osd_message_valid(osd_message_t *m)
{
    return NULL;
}

int event_set_core_defaults(void)
{
    return 1;
}

void event_initialize(void)
{
}

void event_sdl_keydown(int keysym, int keymod)
{
}

void event_sdl_keyup(int keysym, int keymod)
{
}

int event_gameshark_active(void)
{
    return 1;
}

void event_set_gameshark(int active)
{
}