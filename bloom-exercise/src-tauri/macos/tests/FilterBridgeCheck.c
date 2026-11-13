#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void (*callback_t)(void *, const char *);
typedef void (*request_t)(const char *, void *, callback_t);
static request_t bridge_request;
static int phase = 0;

static void completed(void *context, const char *response) {
  (void)context;
  if (phase == 0 && response && strstr(response, "\"ok\":true") && strstr(response, "\"status\":\"unbundled\"")) {
    phase = 1;
    bridge_request("{\"action\":\"startUsageAccess\",\"userId\":\"10000000-0000-4000-8000-000000000001\",\"sessionId\":\"20000000-0000-4000-8000-000000000002\",\"budgetMillis\":60000,\"expiryMillis\":60000,\"requestElapsedMillis\":1,\"requestBoot\":1}", NULL, completed);
    return;
  }
  if (phase == 1 && response && strstr(response, "\"ok\":false")) {
    phase = 2;
    bridge_request("{\"action\":\"hostsPolicyStatus\",\"userId\":\"invalid\"}", NULL, completed);
    return;
  }
  if (phase == 2 && response && strstr(response, "\"ok\":false")) {
    phase = 3;
    bridge_request("{\"action\":\"syncHostsManaged\",\"userId\":\"10000000-0000-4000-8000-000000000001\"}", NULL, completed);
    return;
  }
  if (phase == 3 && response && strstr(response, "\"ok\":false")) {
    phase = 4;
    bridge_request("{\"action\":\"enrollHosts\",\"userId\":\"10000000-0000-4000-8000-000000000001\"}", NULL, completed);
    return;
  }
  if (phase == 4 && response && strstr(response, "\"ok\":false")) {
    phase = 5;
    bridge_request("{\"action\":\"startHostsUsage\",\"userId\":\"10000000-0000-4000-8000-000000000001\"}", NULL, completed);
    return;
  }
  if (phase == 5 && response && strstr(response, "\"ok\":false")) {
    phase = 6;
    bridge_request("{\"action\":\"stopHostsUsage\",\"userId\":\"10000000-0000-4000-8000-000000000001\",\"sessionId\":\"bad\"}", NULL, completed);
    return;
  }
  if (phase != 6 || !response || !strstr(response, "\"ok\":false")) {
    fputs("Bridge returned an unexpected response\n", stderr);
    exit(1);
  }
  puts("macOS protection bridge check passed");
  exit(0);
}

int main(int argc, char **argv) {
  if (argc != 2) return 1;
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) { fputs("Could not load bridge\n", stderr); return 1; }
  bridge_request = (request_t)dlsym(library, "bloom_filter_request");
  if (!bridge_request) { fputs("Bridge entry point is missing\n", stderr); return 1; }
  alarm(10);
  bridge_request("{\"action\":\"inspectBundle\"}", NULL, completed);
  dispatch_main();
}
