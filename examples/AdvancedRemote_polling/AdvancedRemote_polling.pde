// Example of Advanced Remote (Mode 4) that picks a track, starts it playing
// then goes into polling mode, where the iPod sends back elapsed time
// information every 500ms.
//
// If your iPod ends up stuck with the "OK to disconnect" message on its display,
// reset the Arduino. There's a called to AdvancedRemote::disable() in the setup()
// function which should put the iPod back to its normal mode. If that doesn't
// work, or you are unable to reset your Arduino for some reason, resetting the
// iPod will put it back to its normal mode.

#include <AdvancedRemote.h>
#include <Bounce.h>

// This sketch needs to be adapted (change serial port config in setup())
// to be used on a non-Mega, so check the board here so people notice.
#if !defined(__AVR_ATmega1280__)
#error "This example is for the Mega, because it uses Serial3 for the iPod and Serial for debug messages"
#endif

const byte BUTTON_PIN = 22;
const unsigned long DEBOUNCE_MS = 50;

Bounce button(BUTTON_PIN, DEBOUNCE_MS);
AdvancedRemote advancedRemote;

unsigned long chosenSongIndexIntoPlaylist;

//
// our handler (aka callback) implementations;
// these are what get sent data back from the iPod
// when we make requests of it.
//

void feedbackHandler(AdvancedRemote::Feedback feedback, byte cmd)
{
  Serial.print("got feedback of 0x");
  Serial.print(feedback, HEX);
  Serial.print(" for cmd 0x");
  Serial.println(cmd, HEX);

  if (feedback != AdvancedRemote::FEEDBACK_SUCCESS)
  {
    Serial.println("Giving up as feedback wasn't SUCCESS");
    return;
  }

  switch (cmd)
  {
    case AdvancedRemote::CMD_SWITCH_TO_ITEM:
    Serial.println("(Presumably) now at the playlist zero (the main one)");
    Serial.println("Asking for song count");
    advancedRemote.getSongCountInCurrentPlaylist();
    // wait for our song count handler to get called now
    break;

    case AdvancedRemote::CMD_JUMP_TO_SONG_IN_CURRENT_PLAYLIST:
    Serial.println("Jumped to our song");
    Serial.println("Asking for title");
    advancedRemote.getTitle(chosenSongIndexIntoPlaylist);    
    // wait for title handler to get called now
    break;

    case AdvancedRemote::CMD_PLAYBACK_CONTROL:
    Serial.println("playback control complete");
    break;

    case AdvancedRemote::CMD_POLLING_MODE:
    Serial.println("polling mode change complete");
    // from experimentation it starts playing automatically
    break;

  default:
    Serial.println("got feedback we didn't expect");
    break;
  }  
}

void titleHandler(const char *name)
{
  Serial.print("Title: ");
  Serial.println(name);

  Serial.println("Asking for artist");
  advancedRemote.getArtist(chosenSongIndexIntoPlaylist);
  // wait for artist handler to get called
}

void artistHandler(const char *name)
{
  Serial.print("Artist: ");
  Serial.println(name);

  Serial.println("Asking for album");
  advancedRemote.getAlbum(chosenSongIndexIntoPlaylist);
  // wait for album handler to get called
}

void albumHandler(const char *name)
{
  Serial.print("Album: ");
  Serial.println(name);

  Serial.println("Turning on polling (which also seems to make it start playing");
  advancedRemote.setPollingMode(AdvancedRemote::POLLING_START);
  Serial.println("The button will let you do play/pause now. Reset Arduino to go back to normal mode");
}

void currentPlaylistSongCountHandler(unsigned long count)
{
  Serial.print("Current playlist song count is ");
  Serial.println(count, DEC);

  // pick any old song for test porpoises
  chosenSongIndexIntoPlaylist = count / 2;

  Serial.print("Jumping to song at index ");
  Serial.println(chosenSongIndexIntoPlaylist, DEC);
  advancedRemote.jumpToSongInCurrentPlaylist(chosenSongIndexIntoPlaylist);
}

void pollingHandler(AdvancedRemote::PollingCommand command,
                    unsigned long playlistPositionOrelapsedTimeMs)
{
    Serial.print("Poll: ");

    switch (command)
    {
    case AdvancedRemote::POLLING_TRACK_CHANGE:
        Serial.print("track change to: ");
        Serial.println(playlistPositionOrelapsedTimeMs, DEC);
        break;

    case AdvancedRemote::POLLING_ELAPSED_TIME:
        Serial.print("elapsed time: ");
        printTime(playlistPositionOrelapsedTimeMs);
        break;

    default:
        Serial.print("unknown: ");
        Serial.println(playlistPositionOrelapsedTimeMs, DEC);
        break;
    }
}

void printTime(const unsigned long ms)
{
  const unsigned long totalSecs = ms / 1000;
  const unsigned int mins = totalSecs / 60;
  const unsigned int partialSecs = totalSecs % 60;

  Serial.print(mins, DEC);
  Serial.print("m ");
  Serial.print(partialSecs, DEC);
  Serial.println("s");
}

void setup()
{
  pinMode(BUTTON_PIN, INPUT);

  // enable pull-up resistor
  digitalWrite(BUTTON_PIN, HIGH);

  Serial.begin(9600);

  // enable debugging
  // #define IPOD_SERIAL_DEBUG  
  // direct library's log msgs to the default serial port
  //advancedRemote.setLogPrint(Serial);
  // direct library's debug msgs to the default serial port
  //advancedRemote.setDebugPrint(Serial);

  // use Serial3 (Mega-only) to talk to the iPod
  Serial3.begin(iPodSerial::IPOD_SERIAL_RATE);
  advancedRemote.setSerial(Serial3);

  // register callback functions for the things we're going to read
  advancedRemote.setFeedbackHandler(feedbackHandler);
  advancedRemote.setTitleHandler(titleHandler);
  advancedRemote.setArtistHandler(artistHandler);
  advancedRemote.setAlbumHandler(albumHandler);
  advancedRemote.setPollingHandler(pollingHandler);
  advancedRemote.setCurrentPlaylistSongCountHandler(currentPlaylistSongCountHandler);

  // start in simple remote mode
  advancedRemote.disable();
}

void loop()
{
  // service iPod serial. this is who will end up
  // calling our handler functions when responses
  // come back from the iPod
  advancedRemote.loop();

  // use the button as a toggle
  if (button.update() && (button.read() == LOW))
  {
    if (advancedRemote.isCurrentlyEnabled())
    {
      //advancedRemote.disable();
      advancedRemote.controlPlayback(AdvancedRemote::PLAYBACK_CONTROL_PLAY_PAUSE);
    }
    else
    {
      advancedRemote.enable();

      // start our commands - we'll do them in sequence
      // as our handlers get called. for example, this
      // one will call our Feedback handler when it's done
      advancedRemote.switchToItem(AdvancedRemote::ITEM_PLAYLIST, 0);
    }
  }
}











