extern "C" void loadfunctions(void);

extern "C" __attribute__((visibility("default")))
void MangatanOpenJDKLoadFunctions(void) {
  loadfunctions();
}
