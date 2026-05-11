import 'package:flutter/material.dart';

class LoadingWidget extends StatefulWidget {
  const LoadingWidget({super.key});

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    animation = Tween<double>(begin: -40, end: 40).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(animation.value, 0),
                child: Icon(Icons.content_cut, size: 40),
              ),

              Transform.translate(
                offset: Offset(-animation.value, 0),
                child: Icon(Icons.brush, size: 40),
              ),
            ],
          );
        },
      ),
    );
  }
}
