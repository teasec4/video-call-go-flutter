import 'package:flutter/material.dart';

class PeerList extends StatelessWidget {
  final List<String> peers;
  final bool isCallActive;
  final Function(String peerId) onCallPeer;

  const PeerList({
    super.key,
    required this.peers,
    required this.isCallActive,
    required this.onCallPeer,
  });

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty || isCallActive) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Peers:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: peers
                  .map(
                    (peerId) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        onPressed: () => onCallPeer(peerId),
                        child: Text(peerId.substring(0, 8)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
