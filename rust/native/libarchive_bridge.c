#include "archive_entry.h"

int mangatan_libarchive_entry_is_regular(struct archive_entry *entry) {
  return archive_entry_filetype(entry) == AE_IFREG;
}
