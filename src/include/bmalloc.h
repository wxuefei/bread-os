#pragma once
#include <bprint.h>
#include <bstddef.h>
#include <util.h>

namespace bread_os {
namespace kernel {
void *unsafe_malloc(size_t size);
}  // namespace kernel

class MemoryManager {
 public:
  static auto &instance() {
    static MemoryManager _printer;
    return _printer;
  }
  static void init_memory_manager();

 private:
  MemoryManager() = default;
};

class MemoryChunk {
 public:
  uint64_t ptr;
  size_t size;
};

class PhysicalMemoryPage {
 public:
  uint64_t fist_ptr;
  size_t total_size;
  PhysicalMemoryPage *next_page;
};
}  // namespace bread_os
