class ResearchPaper {
  final String title;
  final String authors;
  final String journal;
  final String year;
  final String summary;
  final String url;

  const ResearchPaper({
    required this.title,
    required this.authors,
    required this.journal,
    required this.year,
    required this.summary,
    required this.url,
  });
}

class BenchmarkDataset {
  final String name;
  final String description;
  final String sensorsIncluded;
  final String groundTruthMethod;
  final String downloadUrl;

  const BenchmarkDataset({
    required this.name,
    required this.description,
    required this.sensorsIncluded,
    required this.groundTruthMethod,
    required this.downloadUrl,
  });
}

class TechStackItem {
  final String layer;
  final String technology;
  final String role;

  const TechStackItem({
    required this.layer,
    required this.technology,
    required this.role,
  });
}
