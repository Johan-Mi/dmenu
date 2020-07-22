/* See LICENSE file for copyright and license details. */
/* Default settings; can be overriden by command line. */

static int topbar = 0;                      /* -b  option; if 0, dmenu appears at bottom     */
/* -fn option overrides fonts[0]; default X11 font or font set */
static const char *fonts[] = {
	"fira mono:size=10",
	"JoyPixels:size=8"
};
static const char *prompt      = NULL;      /* -p  option; prompt to the left of input field */
static const char *colors[SchemeLast][2] = {
	/*     fg         bg       */
	[SchemeNorm] = { "#bbc2cf", "#0e0e0e" },
	[SchemeSel] = { "#bbc2cf", "#2257a0" },
	[SchemeSelHighlight] = { "#C678DD", "#091633" },
	[SchemeNormHighlight] = { "#C678DD", "#1C1F24" },
	[SchemeOut] = { "#0e0e0e", "#00ffff" },
	[SchemeCursor] = { "#51afef", "#0e0e0e" },
	[SchemePrompt] = { "#51afef", "#0e0e0e" },
};
/* -l option; if nonzero, dmenu uses vertical list with given number of lines */
static unsigned int lines      = 16;

/*
 * Characters not considered part of a word while deleting words
 * for example: " /?\"&[]"
 */
static const char worddelimiters[] = " ";
