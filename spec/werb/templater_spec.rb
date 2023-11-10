# frozen_string_literal: true

RSpec.describe WERB::Templater do
  it 'generates HTML file using browser.script.iife.js' do
    res = WERB::IIFETemplater.new('view_model.erb', 'root', 'el')
                             .generate('<h1></h1>')
    expect(res).to eq(
      <<~EX.chomp
        <html>
          <head>
            <script src="https://cdn.jsdelivr.net/npm/ruby-head-wasm-wasi@2.1.0/dist/browser.script.iife.js"></script>
            <script type="text/ruby">
              require 'js'

              class ViewModel
                def initialize
                  setup_dom
                end

                private

                def setup_dom
                  @el1 = document.createElement('h1')
                  root.appendChild(@el1)
                end

                def document
                  JS.global[:document]
                end

                def root
                  document.getElementById("root")
                end
              end
            </script>
          </head>
          <body>
            <div id="root"></div>
          </body>
        </html>
      EX
    )
  end

  it 'generates HTML file using browser.umd.js' do
    res = WERB::UMDTemplater.new('view_model.erb', 'root', 'el')
                            .generate('<h1>Hello World</h1>')
    expect(res).to eq(
      <<~EX.chomp
        <html>
          <script src="https://cdn.jsdelivr.net/npm/@ruby/wasm-wasi@latest/dist/browser.umd.js"></script>
          <script>
            const { DefaultRubyVM } = window["ruby-wasm-wasi"];
            const main = async () => {
              // Fetch and instantiate WebAssembly binary
              const response = await fetch(
                //      Tips: Replace the binary with debug info if you want symbolicated stack trace.
                //      (only nightly release for now)
                //      "https://cdn.jsdelivr.net/npm/ruby-3_2-wasm-wasi@next/dist/ruby.debug+stdlib.wasm"
                "https://cdn.jsdelivr.net/npm/ruby-3_2-wasm-wasi@latest/dist/ruby+stdlib.wasm"
              );
              const buffer = await response.arrayBuffer();
              const module = await WebAssembly.compile(buffer);
              const { vm } = await DefaultRubyVM(module);

              vm.printVersion();
              vm.eval(`
                require 'js'

                class ViewModel
                  def initialize
                    setup_dom
                  end

                  private

                  def setup_dom
                    @el1 = document.createElement('h1')
                    root.appendChild(@el1)
                    @el1[:innerText] = @el1[:innerText].to_s + "Hello World"
                  end

                  def document
                    JS.global[:document]
                  end

                  def root
                    document.getElementById("root")
                  end
                end
              `);
            };

            main();
          </script>
          <body>
            <div id="root"></div>
          </body>
        </html>
      EX
    )
  end
end