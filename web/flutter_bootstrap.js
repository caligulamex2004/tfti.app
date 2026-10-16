{{flutter_js}}
{{flutter_build_config}}

const serviceWorkerVersion = {{flutter_service_worker_version}};

// Append the build-specific version query parameter to compiled entrypoint paths
// so browsers always fetch the newly deployed bundle and bypass any stale cached
// unversioned /main.dart.js or /main.dart.wasm responses.
if (
  window._flutter &&
  window._flutter.buildConfig &&
  Array.isArray(window._flutter.buildConfig.builds)
) {
  for (const build of window._flutter.buildConfig.builds) {
    if (build.mainJsPath && !build.mainJsPath.includes('?')) {
      build.mainJsPath = `${build.mainJsPath}?v=${serviceWorkerVersion}`;
    }
    if (build.mainWasmPath && !build.mainWasmPath.includes('?')) {
      build.mainWasmPath = `${build.mainWasmPath}?v=${serviceWorkerVersion}`;
    }
  }
}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: serviceWorkerVersion,
  },
});
