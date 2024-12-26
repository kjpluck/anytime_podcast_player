// Copyright 2020 Ben Hills and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:anytime/bloc/podcast/queue_bloc.dart';
import 'package:anytime/l10n/L.dart';
import 'package:anytime/state/queue_event_state.dart';
import 'package:anytime/ui/widgets/episode_tile.dart';
import 'package:anytime/ui/widgets/platform_progress_indicator.dart';
import 'package:anytime/ui/widgets/tile_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// This class is responsible for rendering the Up Next queue feature.
///
/// The user can see the currently playing item and the current queue. The user can
/// re-arrange items in the queue, remove individual items or completely clear the queue.
class TheQueue extends StatefulWidget {
  const TheQueue({
    super.key,
  });

  @override
  State<TheQueue> createState() => _TheQueueState();
}

class _TheQueueState extends State<TheQueue> {
  @override
  Widget build(BuildContext context) {
    final queueBloc = Provider.of<QueueBloc>(context, listen: false);

    return StreamBuilder<QueueState>(
        initialData: QueueEmptyState(),
        stream: queueBloc.queue,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!.queue.isEmpty) {
              return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10))),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          L.of(context)!.empty_queue_message,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ));
            } else {
              return SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                final episode = snapshot.data!.queue[index];
                final textTheme = Theme.of(context).textTheme;
                return ListTile(
                  key: ValueKey('tilequeue${snapshot.data!.queue[index].guid}'),
                  leading: TileImage(
                    url: episode.thumbImageUrl ?? episode.imageUrl ?? '',
                    size: 56.0,
                    highlight: episode.highlight,
                  ),
                  title: Text(
                    episode.title!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    softWrap: false,
                    style: textTheme.bodyMedium,
                  ),
                  subtitle: EpisodeSubtitle(episode),
                );
              },
                      childCount: snapshot.data!.queue.length,
                      addAutomaticKeepAlives: false));
            }
          } else {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  PlatformProgressIndicator(),
                ],
              ),
            );
          }
        });
  }
}
