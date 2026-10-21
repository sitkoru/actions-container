require 'yaml'
require 'tempfile'
require 'open3'

workflow = YAML.load_file(File.expand_path('../.github/workflows/release.yml', __dir__))
prepare = workflow.fetch('jobs').fetch('build').fetch('steps').find { |step| step['id'] == 'prep' }.fetch('run')

{
  'schedule' => {
    'ref' => 'refs/heads/master',
    'tags' => 'ghcr.io/sitkoru/actions-container:latest,registry.example.invalid/0xdev/actions-container:latest',
    'tags-wasm' => 'ghcr.io/sitkoru/actions-container-wasm:latest,registry.example.invalid/0xdev/actions-container-wasm:latest'
  },
  'release' => {
    'ref' => 'refs/tags/v3.22.0',
    'tags' => 'ghcr.io/sitkoru/actions-container:v3.22.0,ghcr.io/sitkoru/actions-container:v3.22,ghcr.io/sitkoru/actions-container:v3,ghcr.io/sitkoru/actions-container:latest,registry.example.invalid/0xdev/actions-container:v3.22.0,registry.example.invalid/0xdev/actions-container:v3.22,registry.example.invalid/0xdev/actions-container:v3,registry.example.invalid/0xdev/actions-container:latest',
    'tags-wasm' => 'ghcr.io/sitkoru/actions-container-wasm:v3.22.0,ghcr.io/sitkoru/actions-container-wasm:v3.22,ghcr.io/sitkoru/actions-container-wasm:v3,ghcr.io/sitkoru/actions-container-wasm:latest,registry.example.invalid/0xdev/actions-container-wasm:v3.22.0,registry.example.invalid/0xdev/actions-container-wasm:v3.22,registry.example.invalid/0xdev/actions-container-wasm:v3,registry.example.invalid/0xdev/actions-container-wasm:latest'
  }
}.each do |event, expected|
  Tempfile.create('image-tags') do |output|
    env = {
      'GITHUB_EVENT_NAME' => event,
      'GITHUB_REF' => expected.fetch('ref'),
      'GITHUB_SHA' => '0123456789abcdef',
      'GITHUB_OUTPUT' => output.path,
      'PRIVATE_REGISTRY' => 'registry.example.invalid'
    }
    stdout, stderr, status = Open3.capture3(env, 'bash', '-euo', 'pipefail', '-c', prepare)
    raise "#{event}: шаг завершился с ошибкой: #{stdout}#{stderr}" unless status.success?
    actual = File.readlines(output.path).map { |line| line.chomp.split('=', 2) }.to_h
    %w[tags tags-wasm].each do |name|
      raise "#{event} #{name}: #{actual[name].inspect} != #{expected[name].inspect}" unless actual[name] == expected[name]
    end
    puts "verify-release-tags: #{event} OK"
  end
end
