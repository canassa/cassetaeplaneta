/* TinySoundFont + TinyMidiLoader implementation unit, plus a tiny helper
 * API for src/platform/midi.zig (declared there by hand with `extern "c"`,
 * since Zig has no @cImport). Memory comes from libc malloc. */
#define TSF_IMPLEMENTATION
#include "tsf.h"
#define TML_IMPLEMENTATION
#include "tml.h"

#define NOITE_DRUM_CHANNEL 9

/* Give the General MIDI drum channel its percussion bank. tsf channels
 * are created lazily, so this is needed again after every tsf_reset. */
static void noite_setup_channels(tsf *f)
{
	tsf_channel_set_bank_preset(f, NOITE_DRUM_CHANNEL, 128, 0);
}

/* Load a SoundFont from memory and set interleaved stereo output.
 * Returns NULL on bad data. tsf copies what it needs out of `buffer`. */
tsf *noite_tsf_open(const void *buffer, int size, int sample_rate)
{
	tsf *f = tsf_load_memory(buffer, size);
	if (!f) return TSF_NULL;
	tsf_set_output(f, TSF_STEREO_INTERLEAVED, sample_rate, 0.0f);
	noite_setup_channels(f);
	return f;
}

/* Kill every voice and forget all channel state (programs, controllers):
 * the synth is as fresh as after noite_tsf_open. */
void noite_tsf_rewind(tsf *f)
{
	tsf_reset(f);
	noite_setup_channels(f);
}

/* Silence every sounding voice now, keeping channel state. */
void noite_tsf_silence(tsf *f)
{
	int ch;
	for (ch = 0; ch < 16; ch++) tsf_channel_sounds_off_all(f, ch);
}

/* Send every message of `cur` with time <= `ms` to the synth; returns the
 * first message still in the future (NULL at the end of the song). */
tml_message *noite_midi_dispatch(tsf *f, tml_message *cur, unsigned int ms)
{
	for (; cur && cur->time <= ms; cur = cur->next) {
		switch (cur->type) {
		case TML_PROGRAM_CHANGE:
			tsf_channel_set_presetnumber(f, cur->channel, cur->program,
				cur->channel == NOITE_DRUM_CHANNEL);
			break;
		case TML_NOTE_ON:
			tsf_channel_note_on(f, cur->channel, cur->key, cur->velocity / 127.0f);
			break;
		case TML_NOTE_OFF:
			tsf_channel_note_off(f, cur->channel, cur->key);
			break;
		case TML_PITCH_BEND:
			tsf_channel_set_pitchwheel(f, cur->channel, cur->pitch_bend);
			break;
		case TML_CONTROL_CHANGE:
			tsf_channel_midi_control(f, cur->channel, cur->control, cur->control_value);
			break;
		}
	}
	return cur;
}
