#include <stdint.h>
#include <stdbool.h>
#include "piper.hpp"

using namespace piper;

#if defined(_WIN32) && !defined(__MINGW32__)
#    define PIPER_API __declspec(dllexport)
#else
#    define PIPER_API __attribute__ ((visibility ("default")))
#endif

extern "C" {
	/* Callbacks definition */
	typedef void (*AudioCallback)(int16_t* audioBuffer, int length);
	typedef void (*ProgressCallback)(uint16_t progress, size_t total);

#define LIBPIPER_LEVEL_TRACE 0
#define LIBPIPER_LEVEL_DEBUG 1
#define LIBPIPER_LEVEL_INFO 2
#define LIBPIPER_LEVEL_WARN 3
#define LIBPIPER_LEVEL_ERROR 4
#define LIBPIPER_LEVEL_CRITICAL 5
#define LIBPIPER_LEVEL_OFF 6

	PIPER_API void setLogLevel(int logLevel);

	/* Working with structs functions */
	PIPER_API PiperConfig* createPiperConfig(char* eSpeakDataPath, char* dllPath) {
		auto config = new PiperConfig();
		config->dllPath = dllPath;
		config->eSpeakDataPath = eSpeakDataPath;
		return config;
	}
	PIPER_API void destroyPiperConfig(PiperConfig* config) {
		delete config;
	}

	PIPER_API Voice* createVoice() {
		return new Voice();
	}
	PIPER_API void destroyVoice(Voice* voice) {
		delete voice;
	}

	PIPER_API SynthesisResult* createSynthesisResult() {
		return new SynthesisResult();
	}
	PIPER_API void destroySynthesisResult(SynthesisResult* config) {
		delete config;
	}

	/* Change SynthesisResult fields */
	PIPER_API void setSynthesisConfigNoiseScale(Voice* voice, float value) {
		voice->synthesisConfig.noiseScale = value;
	}

	PIPER_API void setSynthesisConfigLengthScale(Voice* voice, float value) {
		voice->synthesisConfig.lengthScale = value;
	}

	PIPER_API void setSynthesisConfigNoiseW(Voice* voice, float value) {
		voice->synthesisConfig.noiseW = value;
	}

	PIPER_API void setSynthesisConfigSentenceSilence(Voice* voice, float value) {
		voice->synthesisConfig.sentenceSilenceSeconds = value;
	}

	PIPER_API void setSynthesisConfigSpeakerId(Voice* voice, SpeakerId speakerId) {
		voice->synthesisConfig.speakerId = speakerId;
	}

	/* Init/Destroy functions */
	PIPER_API void initializePiper(PiperConfig* config);
	PIPER_API void terminatePiper(PiperConfig* config);

	/* Main library API */
	PIPER_API void loadVoice(PiperConfig* config, const char* modelPath, const char* modelConfigPath, Voice* voice, SpeakerId* speakerId);
	PIPER_API void textToAudio(PiperConfig* config, Voice* voice, const char* text, SynthesisResult* result, AudioCallback audioCallback, ProgressCallback progressCallback);
	PIPER_API void textToWavFile(PiperConfig* config, Voice* voice, const char* text, const char* audioFile, SynthesisResult* result, ProgressCallback progressCallback);
}
