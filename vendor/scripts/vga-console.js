(function () {
  function createVGAConsoleFeature(deps) {
    const specialKeyMap = {
      Enter: 13,
      Backspace: 8,
      Tab: 9,
      Escape: 27,
      ArrowLeft: 37,
      ArrowUp: 38,
      ArrowRight: 39,
      ArrowDown: 40,
      Delete: 46,
      Insert: 45,
      Home: 36,
      End: 35,
      PageUp: 33,
      PageDown: 34,
      F1: 112,
      F2: 113,
      F3: 114,
      F4: 115,
      F5: 116,
      F6: 117,
      F7: 118,
      F8: 119,
      F9: 120,
      F10: 121,
      F11: 122,
      F12: 123,
    };

    let mounted = false;
    let listenersBound = false;

    function mount() {
      if (mounted) {
        return;
      }

      const host = document.getElementById("vga-console-host");
      if (!host) {
        return;
      }

      host.innerHTML = `
        <textarea
          id="vga-keyboard-proxy"
          autocomplete="off"
          autocorrect="off"
          autocapitalize="off"
          spellcheck="false"
          aria-hidden="true"
          tabindex="-1"
        ></textarea>
        <div class="row" id="vga-console-row">
          <div class="col-md-12">
            <div class="panel panel-default">
              <div class="panel-heading">
                <h4>VGA 控制台</h4>
                <div class="btn-group" role="group">
                  <button
                    type="button"
                    class="btn btn-sm btn-default"
                    id="toggle-screen-btn"
                  >
                    显示/隐藏
                  </button>
                </div>
              </div>
              <div class="panel-body" id="vga-screen-panel">
                <div id="screen_container"></div>
              </div>
            </div>
          </div>
        </div>
      `;

      mounted = true;
    }

    function getElements() {
      mount();
      return {
        row: document.getElementById("vga-console-row"),
        panel: document.getElementById("vga-screen-panel"),
        proxy: document.getElementById("vga-keyboard-proxy"),
        screenContainer: document.getElementById("screen_container"),
        toggleButton: document.getElementById("toggle-screen-btn"),
        terminal: document.getElementById("terminal"),
      };
    }

    function sendKey(event) {
      const emulator = deps.getEmulator();
      if (!emulator) {
        return false;
      }

      if (
        event.ctrlKey ||
        event.altKey ||
        event.metaKey ||
        event.key === "Shift" ||
        event.key === "Control" ||
        event.key === "Alt" ||
        event.key === "Meta"
      ) {
        return false;
      }

      if (specialKeyMap[event.key] !== undefined) {
        emulator.keyboard_send_keys([specialKeyMap[event.key]]);
        return true;
      }

      if (event.key.length === 1) {
        emulator.keyboard_send_text(event.key);
        return true;
      }

      return false;
    }

    function bindListeners() {
      if (listenersBound) {
        return;
      }

      const { screenContainer, proxy, panel, toggleButton } = getElements();

      window.addEventListener(
        "keydown",
        function (e) {
          if (deps.getActiveInputTarget() !== "vga") {
            return;
          }

          if (sendKey(e)) {
            e.preventDefault();
            e.stopPropagation();
          }
        },
        true,
      );

      if (proxy) {
        proxy.addEventListener("keydown", function (e) {
          if (deps.getActiveInputTarget() !== "vga") {
            return;
          }

          if (sendKey(e)) {
            e.preventDefault();
            e.stopPropagation();
          }
        });

        proxy.addEventListener("input", function () {
          const emulator = deps.getEmulator();
          if (deps.getActiveInputTarget() !== "vga" || !emulator) {
            proxy.value = "";
            return;
          }

          if (proxy.value) {
            emulator.keyboard_send_text(proxy.value);
          }

          proxy.value = "";
        });
      }

      if (screenContainer) {
        screenContainer.addEventListener("click", function () {
          deps.setInputTarget("vga");
          screenContainer.focus();

          const canvas = screenContainer.querySelector("canvas");
          if (canvas) {
            canvas.focus?.();
          }

          window.focus();

          if (proxy) {
            proxy.value = "";
            proxy.focus();
          }
        });

        screenContainer.addEventListener("keydown", function (e) {
          if (sendKey(e)) {
            e.preventDefault();
            e.stopPropagation();
          }
        });

        screenContainer.addEventListener("focus", function () {
          deps.setInputTarget("vga");
        });
      }

      if (toggleButton && panel) {
        toggleButton.addEventListener("click", function () {
          panel.style.display = panel.style.display === "none" ? "block" : "none";
        });
      }

      listenersBound = true;
    }

    return {
      enabled: true,
      setup() {
        mount();
        bindListeners();
      },
      prepareScreenContainer() {
        const { screenContainer } = getElements();
        if (!screenContainer) {
          return null;
        }

        screenContainer.tabIndex = 0;
        screenContainer.setAttribute(
          "title",
          "点击此处聚焦虚拟机屏幕并发送键盘输入",
        );
        screenContainer.innerHTML = `
          <div style="white-space: pre; font: 14px monospace; line-height: 14px"></div>
          <canvas style="display: none"></canvas>
        `;
        return screenContainer;
      },
      applyInputTarget(target) {
        const { proxy, screenContainer, terminal } = getElements();
        const emulator = deps.getEmulator();
        const resolvedTarget = target === "vga" ? "vga" : "terminal";

        if (emulator && typeof emulator.keyboard_set_enabled === "function") {
          emulator.keyboard_set_enabled(resolvedTarget === "vga");
        }

        if (resolvedTarget === "terminal") {
          proxy?.blur();
          screenContainer?.blur?.();
          if (window.getSelection().toString().length === 0) {
            if (typeof deps.focusTerminal === "function") {
              deps.focusTerminal();
            } else {
              terminal?.focus();
            }
          }
          return resolvedTarget;
        }

        terminal?.blur();
        return resolvedTarget;
      },
    };
  }

  window.createVGAConsoleFeature = createVGAConsoleFeature;
})();
