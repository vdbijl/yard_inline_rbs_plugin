# Changelog

## 0.1.0

First release.

- Types from `@rbs` tags, `#:` comments and trailing `#:` comments become `@param`, `@return`,
  `@yield` and `@yieldreturn` tags.
- The declarations of `.rbs` files become the same tags.
- A method with overloads gets an `@overload` tag for each signature.
- A tuple is `Array(Integer, String)`, a record is `Hash{Symbol => Integer}` and an intersection is
  `A & B`.
