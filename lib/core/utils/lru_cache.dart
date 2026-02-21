import 'dart:collection';

/// Generic LRU (Least Recently Used) cache with configurable max size.
/// Used for memory-efficient hex data caching.
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  // Statistics for monitoring
  int _hits = 0;
  int _misses = 0;

  LruCache({this.maxSize = 500});

  /// Get cache statistics
  int get hits => _hits;
  int get misses => _misses;
  int get size => _cache.length;
  double get hitRate => _hits + _misses > 0 ? _hits / (_hits + _misses) : 0;

  /// Get a value from cache, returns null if not found.
  /// Moves accessed item to end (most recently used).
  V? get(K key) {
    if (_cache.containsKey(key)) {
      _hits++;
      // Move to end (most recently used)
      final value = _cache.remove(key)!;
      _cache[key] = value;
      return value;
    }
    _misses++;
    return null;
  }

  /// Check if key exists without affecting LRU order.
  bool containsKey(K key) => _cache.containsKey(key);

  /// Put a value in cache. Evicts oldest if at max size.
  void put(K key, V value) {
    // If key exists, remove it first (will be re-added at end)
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }
    // Evict oldest if at capacity
    else if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Update a value if it exists, without changing LRU order.
  void update(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache[key] = value;
    }
  }

  /// Remove a specific key.
  V? remove(K key) => _cache.remove(key);

  /// Clear all cached data.
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Get all keys (for iteration, e.g., aggregation).
  Iterable<K> get keys => _cache.keys;

  /// Get all values.
  Iterable<V> get values => _cache.values;

  /// Get all entries.
  Iterable<MapEntry<K, V>> get entries => _cache.entries;

  /// Iterate over all key-value pairs.
  void forEach(void Function(K key, V value) action) {
    _cache.forEach(action);
  }

  /// Reset statistics (useful after warmup period).
  void resetStats() {
    _hits = 0;
    _misses = 0;
  }

  @override
  String toString() =>
      'LruCache(size: $size/$maxSize, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
}
