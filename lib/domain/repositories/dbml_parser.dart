import '../entities/schema_models.dart';

abstract interface class DbmlBackend {
  SchemaModel parse(String source);
}
