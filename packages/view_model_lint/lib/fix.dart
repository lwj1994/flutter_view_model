/// Applies view_model_lint quick fixes across a package from the command line.
library;

export 'src/batch_fix.dart'
    show AppliedFix, FixSummary, ReportedDiagnostic, analyzeWithDart, fixAll;
