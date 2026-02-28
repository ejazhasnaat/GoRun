enum RunCategory { freeRun, fiveK, tenK, halfMarathon, marathon }

extension RunCategoryExtension on RunCategory {
  String get label {
    switch (this) {
      case RunCategory.freeRun:
        return 'Free Run';
      case RunCategory.fiveK:
        return '5K';
      case RunCategory.tenK:
        return '10K';
      case RunCategory.halfMarathon:
        return 'Half Marathon';
      case RunCategory.marathon:
        return 'Marathon';
    }
  }

  String get distanceLabel {
    switch (this) {
      case RunCategory.freeRun:
        return 'Any Distance';
      case RunCategory.fiveK:
        return '5 km';
      case RunCategory.tenK:
        return '10 km';
      case RunCategory.halfMarathon:
        return '21.1 km';
      case RunCategory.marathon:
        return '42.2 km';
    }
  }
}
