///|
/// An Item is the fundamental data unit flowing between nodes.
/// Each item carries a JSON object (key-value pairs).
/// This mirrors n8n's INodeExecutionData.json field.
pub(all) struct Item {
  json : Map[String, Json]
} derive(Show, Debug, ToJson, Eq)

///|
/// Create an empty item.
pub fn Item::empty() -> Item {
  { json: {} }
}

///|
/// Create an item from key-value pairs.
pub fn Item::from_pairs(pairs : Array[(String, Json)]) -> Item {
  let json : Map[String, Json] = {}
  for pair in pairs {
    json[pair.0] = pair.1
  }
  { json, }
}

///|
/// Create a single item with one field.
pub fn Item::of(key : String, value : Json) -> Item {
  Item::from_pairs([(key, value)])
}

///|
/// Get a field value from the item.
pub fn Item::get(self : Item, key : String) -> Json? {
  self.json.get(key)
}

///|
/// Set a field on the item, returning a new item.
pub fn Item::set(self : Item, key : String, value : Json) -> Item {
  let json : Map[String, Json] = {}
  for k, v in self.json {
    json[k] = v
  }
  json[key] = value
  { json, }
}

///|
/// Merge another item's fields into this item. Fields from `other` take priority.
pub fn Item::merge(self : Item, other : Item) -> Item {
  let json : Map[String, Json] = {}
  for k, v in self.json {
    json[k] = v
  }
  for k, v in other.json {
    json[k] = v
  }
  { json, }
}
