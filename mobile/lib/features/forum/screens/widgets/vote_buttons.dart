import 'package:flutter/material.dart';
import '../../../../core/theme/cartok_colors.dart';

class VoteButtons extends StatelessWidget {
  const VoteButtons({
    super.key,
    required this.score,
    required this.myVote,
    required this.onUpvote,
    required this.onDownvote,
  });

  final int score;
  final int? myVote;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  @override
  Widget build(BuildContext context) {
    final scoreColor = myVote == 1
        ? CartokColors.redline
        : myVote == -1
            ? CartokColors.danger
            : CartokColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: myVote == 1 ? CartokColors.redline : CartokColors.textTertiary,
          ),
          onPressed: onUpvote,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            '$score',
            key: ValueKey(score),
            style: TextStyle(color: scoreColor, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: myVote == -1 ? CartokColors.danger : CartokColors.textTertiary,
          ),
          onPressed: onDownvote,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
