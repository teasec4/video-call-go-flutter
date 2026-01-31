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

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Peers (${peers.length})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: peers
                  .map(
                    (peerId) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => onCallPeer(peerId),
                        child: Text(
                          peerId.substring(0, 8),
                          style: const TextStyle(fontSize: 12),
                        ),
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
