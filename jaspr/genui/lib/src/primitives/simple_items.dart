/// A JSON object, as produced by `jsonDecode`.
typedef JsonMap = Map<String, Object?>;

/// The key under which a surface's ID travels in event payloads.
const String surfaceIdKey = 'surfaceId';

/// The catalog ID of the basic web catalog.
///
/// This is the A2UI basic catalog: the component names and property shapes
/// match the specification, so an agent written against the basic catalog
/// drives this renderer without changes.
const String basicCatalogId =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// The schema URI for the A2UI common types.
const String commonTypesSchemaId =
    'https://a2ui.org/specification/v0_9/common_types.json';
