// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/audio_bloc.dart';
import 'package:anytime/bloc/podcast/episode_bloc.dart';
import 'package:anytime/bloc/podcast/podcast_bloc.dart';
import 'package:anytime/entities/downloadable.dart';
import 'package:anytime/entities/episode.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/services/audio/audio_player_service.dart';
import 'package:anytime/ui/podcast/episode_details.dart';
import 'package:anytime/ui/podcast/transport_controls.dart';
import 'package:anytime/ui/widgets/action_text.dart';
import 'package:anytime/ui/widgets/tile_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

/// This class builds a tile for each episode in the podcast feed.
class EpisodeTile extends StatelessWidget {
  final Episode episode;
  final bool download;
  final bool play;
  final bool playing;
  final bool queued;

  const EpisodeTile({
    super.key,
    required this.episode,
    required this.download,
    required this.play,
    this.playing = false,
    this.queued = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);

    if (mediaQueryData.accessibleNavigation) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return _CupertinoAccessibleEpisodeTile(
          episode: episode,
          play: play,
          playing: playing,
        );
      } else {
        return _AccessibleEpisodeTile(
          episode: episode,
          play: play,
          playing: playing,
        );
      }
    } else {
      return ExpandableEpisodeTile(
        episode: episode,
        download: download,
        play: play,
        playing: playing,
        queued: queued,
      );
    }
  }
}

/// An EpisodeTitle is built with an [ExpansionTile] widget and displays the episode's
/// basic details, thumbnail and play button.
///
/// It can then be expanded to present addition information about the episode and further
/// controls.
///
/// TODO: Replace [Opacity] with [Container] with a transparent colour.
class ExpandableEpisodeTile extends StatefulWidget {
  final Episode episode;
  final bool download;
  final bool play;
  final bool playing;
  final bool queued;

  const ExpandableEpisodeTile({
    super.key,
    required this.episode,
    required this.download,
    required this.play,
    this.playing = false,
    this.queued = false,
  });

  @override
  State<ExpandableEpisodeTile> createState() => _ExpandableEpisodeTileState();
}

class _ExpandableEpisodeTileState extends State<ExpandableEpisodeTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      key: Key('PT${widget.episode.guid}'),
      onTap: () {
        showModalBottomSheet<void>(
            barrierLabel: L.of(context)!.scrim_episode_details_selector,
            context: context,
            backgroundColor: theme.bottomAppBarTheme.color,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.0),
                topRight: Radius.circular(10.0),
              ),
            ),
            builder: (context) {
              return EpisodeDetails(
                episode: widget.episode,
              );
            });
      },
      trailing: Opacity(
        opacity: widget.episode.queued ? 1.0 : 0.5,
        child: EpisodeTransportControls(
          episode: widget.episode,
          download: widget.download,
          play: widget.play,
        ),
      ),
      leading: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.bottomLeft,
          fit: StackFit.passthrough,
          children: <Widget>[
            Opacity(
              opacity: widget.episode.queued ? 1.0 : 0.5,
              child: TileImage(
                url: widget.episode.thumbImageUrl ?? widget.episode.imageUrl!,
                size: 56.0,
                highlight: widget.episode.highlight,
              ),
            ),
            SizedBox(
              height: 5.0,
              width: 56.0 * (widget.episode.percentagePlayed / 100),
              child: Container(
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
      subtitle: Opacity(
        opacity: widget.episode.queued ? 1.0 : 0.5,
        child: EpisodeSubtitle(widget.episode),
      ),
      title: Opacity(
        opacity: widget.episode.queued ? 1.0 : 0.5,
        child: Text(
          widget.episode.title!,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          softWrap: false,
          style: textTheme.bodyMedium,
        ),
      ),
      
    );
  }
}

/// This is an accessible version of the episode tile that uses Apple theming.
/// When the tile is tapped, an iOS menu will appear with the relevant options.
class _CupertinoAccessibleEpisodeTile extends StatefulWidget {
  final Episode episode;
  final bool play;
  final bool playing;

  const _CupertinoAccessibleEpisodeTile({
    required this.episode,
    required this.play,
    this.playing = false,
  });

  @override
  State<_CupertinoAccessibleEpisodeTile> createState() => _CupertinoAccessibleEpisodeTileState();
}

class _CupertinoAccessibleEpisodeTileState extends State<_CupertinoAccessibleEpisodeTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final episodeBloc = Provider.of<EpisodeBloc>(context);
    final podcastBloc = Provider.of<PodcastBloc>(context);

    return StreamBuilder<_PlayerControlState>(
        stream: Rx.combineLatest2(audioBloc.playingState!, audioBloc.nowPlaying!,
            (AudioState audioState, Episode? episode) => _PlayerControlState(audioState, episode)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }

          final audioState = snapshot.data!.audioState;
          final nowPlaying = snapshot.data!.episode;
          final currentlyPlaying = nowPlaying?.guid == widget.episode.guid && audioState == AudioState.playing;
          final currentlyPaused = nowPlaying?.guid == widget.episode.guid && audioState == AudioState.pausing;

          return Semantics(
            button: true,
            child: ListTile(
              key: Key('PT${widget.episode.guid}'),
              leading: ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    Opacity(
                      opacity: widget.episode.played ? 0.5 : 1.0,
                      child: TileImage(
                        url: widget.episode.thumbImageUrl ?? widget.episode.imageUrl!,
                        size: 56.0,
                        highlight: widget.episode.highlight,
                      ),
                    ),
                    SizedBox(
                      height: 5.0,
                      width: 56.0 * (widget.episode.percentagePlayed / 100),
                      child: Container(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              subtitle: Opacity(
                opacity: widget.episode.played ? 0.5 : 1.0,
                child: EpisodeSubtitle(widget.episode),
              ),
              title: Opacity(
                opacity: widget.episode.played ? 0.5 : 1.0,
                child: Text(
                  widget.episode.title!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: false,
                  style: textTheme.bodyMedium,
                ),
              ),
              onTap: () {
                showCupertinoModalPopup<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return CupertinoActionSheet(
                      actions: <Widget>[
                        if (currentlyPlaying)
                          CupertinoActionSheetAction(
                            isDefaultAction: true,
                            onPressed: () {
                              audioBloc.transitionState(TransitionState.pause);
                              Navigator.pop(context, 'Cancel');
                            },
                            child: Text(L.of(context)!.pause_button_label),
                          ),
                        if (currentlyPaused)
                          CupertinoActionSheetAction(
                            isDefaultAction: true,
                            onPressed: () {
                              audioBloc.transitionState(TransitionState.play);
                              Navigator.pop(context, 'Cancel');
                            },
                            child: Text(L.of(context)!.resume_button_label),
                          ),
                        if (!currentlyPlaying && !currentlyPaused)
                          CupertinoActionSheetAction(
                            isDefaultAction: true,
                            onPressed: () {
                              audioBloc.play(widget.episode);
                              Navigator.pop(context, 'Cancel');
                            },
                            child: widget.episode.downloaded
                                ? Text(L.of(context)!.play_download_button_label)
                                : Text(L.of(context)!.play_button_label),
                          ),
                        if (widget.episode.downloadState == DownloadState.queued ||
                            widget.episode.downloadState == DownloadState.downloading)
                          CupertinoActionSheetAction(
                            isDefaultAction: false,
                            onPressed: () {
                              episodeBloc.deleteDownload(widget.episode);
                              Navigator.pop(context, 'Cancel');
                            },
                            child: Text(L.of(context)!.cancel_download_button_label),
                          ),
                        if (widget.episode.downloadState != DownloadState.downloading)
                          CupertinoActionSheetAction(
                            isDefaultAction: false,
                            onPressed: () {
                              if (widget.episode.downloaded) {
                                episodeBloc.deleteDownload(widget.episode);
                                Navigator.pop(context, 'Cancel');
                              } else {
                                podcastBloc.downloadEpisode(widget.episode);
                                Navigator.pop(context, 'Cancel');
                              }
                            },
                            child: widget.episode.downloaded
                                ? Text(L.of(context)!.delete_episode_button_label)
                                : Text(L.of(context)!.download_episode_button_label),
                          ),
                        if (widget.episode.played)
                          CupertinoActionSheetAction(
                            isDefaultAction: false,
                            onPressed: () {
                              episodeBloc.togglePlayed(widget.episode);
                              Navigator.pop(context, 'Cancel');
                            },
                            child: Text(L.of(context)!.semantics_mark_episode_unplayed),
                          ),
                        if (!widget.episode.played)
                          CupertinoActionSheetAction(
                            isDefaultAction: false,
                            onPressed: () {
                              episodeBloc.togglePlayed(widget.episode);
                              Navigator.pop(context, 'Cancel');
                            },
                            child: Text(L.of(context)!.semantics_mark_episode_played),
                          ),
                        CupertinoActionSheetAction(
                          isDefaultAction: false,
                          onPressed: () {
                            Navigator.pop(context, 'Cancel');
                            showModalBottomSheet<void>(
                                context: context,
                                barrierLabel: L.of(context)!.scrim_episode_details_selector,
                                backgroundColor: theme.bottomAppBarTheme.color,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(10.0),
                                    topRight: Radius.circular(10.0),
                                  ),
                                ),
                                builder: (context) {
                                  return EpisodeDetails(
                                    episode: widget.episode,
                                  );
                                });
                          },
                          child: Text(L.of(context)!.episode_details_button_label),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        isDefaultAction: false,
                        onPressed: () {
                          Navigator.pop(context, 'Close');
                        },
                        child: Text(L.of(context)!.close_button_label),
                      ),
                    );
                  },
                );
              },
            ),
          );
        });
  }
}

/// This is an accessible version of the episode tile that uses Android theming.
/// When the tile is tapped, an Android dialog menu will appear with the relevant
/// options.
class _AccessibleEpisodeTile extends StatefulWidget {
  final Episode episode;
  final bool play;
  final bool playing;

  const _AccessibleEpisodeTile({
    required this.episode,
    required this.play,
    this.playing = false,
  });

  @override
  State<_AccessibleEpisodeTile> createState() => _AccessibleEpisodeTileState();
}

class _AccessibleEpisodeTileState extends State<_AccessibleEpisodeTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final episodeBloc = Provider.of<EpisodeBloc>(context);
    final podcastBloc = Provider.of<PodcastBloc>(context);

    return StreamBuilder<_PlayerControlState>(
        stream: Rx.combineLatest2(audioBloc.playingState!, audioBloc.nowPlaying!,
            (AudioState audioState, Episode? episode) => _PlayerControlState(audioState, episode)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }

          final audioState = snapshot.data!.audioState;
          final nowPlaying = snapshot.data!.episode;
          final currentlyPlaying = nowPlaying?.guid == widget.episode.guid && audioState == AudioState.playing;
          final currentlyPaused = nowPlaying?.guid == widget.episode.guid && audioState == AudioState.pausing;

          return ListTile(
            key: Key('PT${widget.episode.guid}'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Semantics(
                    header: true,
                    child: SimpleDialog(
                      //TODO: Fix this - should not be hardcoded text
                      title: const Text('Episode Actions'),
                      children: <Widget>[
                        if (currentlyPlaying)
                          SimpleDialogOption(
                            onPressed: () {
                              audioBloc.transitionState(TransitionState.pause);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.pause_button_label),
                          ),
                        if (currentlyPaused)
                          SimpleDialogOption(
                            onPressed: () {
                              audioBloc.transitionState(TransitionState.play);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.resume_button_label),
                          ),
                        if (!currentlyPlaying && !currentlyPaused && widget.episode.downloaded)
                          SimpleDialogOption(
                            onPressed: () {
                              audioBloc.play(widget.episode);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.play_download_button_label),
                          ),
                        if (!currentlyPlaying && !currentlyPaused && !widget.episode.downloaded)
                          SimpleDialogOption(
                            onPressed: () {
                              audioBloc.play(widget.episode);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.play_button_label),
                          ),
                        if (widget.episode.downloadState == DownloadState.queued ||
                            widget.episode.downloadState == DownloadState.downloading)
                          SimpleDialogOption(
                            onPressed: () {
                              episodeBloc.deleteDownload(widget.episode);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.cancel_download_button_label),
                          ),
                        if (widget.episode.downloadState != DownloadState.downloading && widget.episode.downloaded)
                          SimpleDialogOption(
                            onPressed: () {
                              episodeBloc.deleteDownload(widget.episode);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.delete_episode_button_label),
                          ),
                        if (widget.episode.downloadState != DownloadState.downloading && !widget.episode.downloaded)
                          SimpleDialogOption(
                            onPressed: () {
                              podcastBloc.downloadEpisode(widget.episode);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.download_episode_button_label),
                          ),
                        if (widget.episode.played)
                          SimpleDialogOption(
                            onPressed: () {
                              episodeBloc.togglePlayed(widget.episode);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.semantics_mark_episode_unplayed),
                          ),
                        if (!widget.episode.played)
                          SimpleDialogOption(
                            onPressed: () {
                              episodeBloc.togglePlayed(widget.episode);
                              Navigator.pop(context, '');
                            },
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                            child: Text(L.of(context)!.semantics_mark_episode_played),
                          ),
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.pop(context, '');
                            showModalBottomSheet<void>(
                                context: context,
                                barrierLabel: L.of(context)!.scrim_episode_details_selector,
                                backgroundColor: theme.bottomAppBarTheme.color,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(10.0),
                                    topRight: Radius.circular(10.0),
                                  ),
                                ),
                                builder: (context) {
                                  return EpisodeDetails(
                                    episode: widget.episode,
                                  );
                                });
                          },
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                          child: Text(L.of(context)!.episode_details_button_label),
                        ),
                        SimpleDialogOption(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                          // child: Text(L.of(context)!.close_button_label),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              child: ActionText(L.of(context)!.close_button_label),
                              onPressed: () {
                                Navigator.pop(context, '');
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            leading: ExcludeSemantics(
              child: Stack(
                alignment: Alignment.bottomLeft,
                fit: StackFit.passthrough,
                children: <Widget>[
                  Opacity(
                    opacity: widget.episode.queued ? 1.0 : 0.5,
                    child: TileImage(
                      url: widget.episode.thumbImageUrl ?? widget.episode.imageUrl!,
                      size: 56.0,
                      highlight: widget.episode.highlight,
                    ),
                  ),
                  SizedBox(
                    height: 5.0,
                    width: 56.0 * (widget.episode.percentagePlayed / 100),
                    child: Container(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            subtitle: Opacity(
              opacity: widget.episode.queued ? 1.0 : 0.5,
              child: EpisodeSubtitle(widget.episode),
            ),
            title: Opacity(
              opacity: widget.episode.queued ? 1.0 : 0.5,
              child: Text(
                '${widget.episode.title!} ${widget.episode.queued}',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                softWrap: false,
                style: textTheme.bodyMedium,
              ),
            ),
          );
        });
  }
}

class EpisodeTransportControls extends StatelessWidget {
  final Episode episode;
  final bool download;
  final bool play;

  const EpisodeTransportControls({
    super.key,
    required this.episode,
    required this.download,
    required this.play,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (play) {
      buttons.add(Semantics(
        container: true,
        child: PlayControl(
          episode: episode,
        ),
      ));
    }

    return SizedBox(
      width: (buttons.length * 48.0),
      child: Row(
        children: <Widget>[...buttons],
      ),
    );
  }
}

class EpisodeSubtitle extends StatelessWidget {
  final Episode episode;
  final String date;
  final Duration length;

  EpisodeSubtitle(this.episode, {super.key})
      : date = episode.publicationDate == null
            ? ''
            : DateFormat(episode.publicationDate!.year == DateTime.now().year ? 'd MMM' : 'd MMM yyyy')
                .format(episode.publicationDate!),
        length = Duration(seconds: episode.duration);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    var timeRemaining = episode.timeRemaining;

    String title;

    if (length.inSeconds > 0) {
      if (length.inSeconds < 60) {
        title = '$date • ${length.inSeconds} sec';
      } else {
        title = '$date • ${length.inMinutes} min';
      }
    } else {
      title = date;
    }

    if (timeRemaining.inSeconds > 0) {
      if (timeRemaining.inSeconds < 60) {
        title = '$title / ${timeRemaining.inSeconds} sec left';
      } else {
        title = '$title / ${timeRemaining.inMinutes} min left';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: textTheme.bodySmall,
      ),
    );
  }
}

/// This class acts as a wrapper between the current audio state and
/// downloadables. Saves all that nesting of StreamBuilders.
class _PlayerControlState {
  final AudioState audioState;
  final Episode? episode;

  _PlayerControlState(this.audioState, this.episode);
}
