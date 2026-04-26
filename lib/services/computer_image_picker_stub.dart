class PickedComputerImage {
  final List<int> bytes;
  final String mimeType;
  final String name;

  const PickedComputerImage({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });
}

Future<PickedComputerImage?> pickImageFromComputer() async => null;
