import 'dart:ui';
import 'package:flutter/material.dart';

class SensitiveMediaBox extends StatefulWidget {
  final double width;
  final double height;
  final bool sensitive;
  final Widget child;

  const SensitiveMediaBox({
    super.key,
    required this.width,
    required this.height,
    required this.sensitive,
    required this.child,
  });

  @override
  State<SensitiveMediaBox> createState() => _SensitiveMediaBoxState();
}

class _SensitiveMediaBoxState extends State<SensitiveMediaBox> {
  bool revealed = false;

  @override
  Widget build(BuildContext context) {
    final bool mustHide = widget.sensitive && !revealed;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,

            if (mustHide) ...[
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.black.withOpacity(0.25)),
              ),
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(10),
                color: Colors.black.withOpacity(0.40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    const Text(
                      "Contenido sensible",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => revealed = true),
                      child: const Text("Ver"),
                    )
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
