# frozen_string_literal: true

require 'etc'
require 'rake'
require_relative '../monkeypatch'
require_relative '../utils'
require_relative './asset'

module Tester
  # Base test runner. It includes the following capabilities:
  # * identify all directories where things to test are located
  # * execute a specific command, save its output and execution result into a
  #   hash of Result objects
  class TestRunner
    attr_reader :assets
    ASSET = ChartAsset
    KUBERNETES_VERSIONS = '1.19,1.16'
    DEFAULT_TESTS = %w[lint validate diff].freeze
    EXCLUDE = [].freeze

    # Instantiate a new TestRunner and find
    # @param pattern [String] A glob pattern used to find assets.
    # @param options [Hash<Symbol, Array<String>>] can enumerate tests to run and assets names as an array
    def initialize(pattern, options)
      @validate_options = { kubeyaml: which('kubeyaml'), kube_versions: KUBERNETES_VERSIONS }
      @assets = find_assets(pattern, options.fetch(:assets, nil))
      # If you're unfamiliar with ruby: using self.class here
      # ensures we can properly override default tests in the children classes.
      @tests = options.fetch(:tests, self.class::DEFAULT_TESTS)
    end

    # Run the tests that were selected.
    def run
      assets = @assets.values
      # First let's filter our assets if there is such an option defined
      if @tests.include? 'lint'
        # We have no issue with overwhelming any charts repo at this point.
        tp = ThreadPool.new(nthreads: Etc.nprocessors)
        assets.each do |asset|
          tp.run do
            asset.lint
          end
        end
        tp.join
      end
      if @tests.include? 'diff'
        back_to_origin do |origin|
          tp = ThreadPool.new(nthreads: Etc.nprocessors)
          assets.each do |asset|
            tp.run do
              asset.diff origin
            end
          end
          # Wait for all the work to be done before returning
          # Please note: this needs to be here or some threads might not find
          # the directory.
          tp.join
        end
      end
      assets.each { |a| a.validate @validate_options } if @tests.include? 'validate'
    end

    # Create a copy that is a checkout of the original repo, for diffing
    # returns the name of this checkout to the block given
    # @param block [Block]
    def back_to_origin(&block)
      Dir.mktmpdir do |orig_dir|
        FileUtils.cp_r('.', orig_dir)
        git = Git.open(orig_dir)
        git.reset_hard('HEAD')
        git.back_to('origin/master') do
          block.call orig_dir
        end
      end
    end

    # Get the assets that did pass the test
    # @return [Hash<String,BaseTestAsset>]
    def succeded
      @assets.select { |_, v| v.ok? }
    end

    # Get the assets that did not pass the test
    # @return [Hash<String,BaseTestAsset>]
    def failed
      @assets.reject { |_, v| v.ok? }
    end

    private

    # Find the assets we need to run on.
    # @param pattern [String] the glob pattern
    # @param to_run [Array<String>] the list of asset names to run on.
    # @return Hash[]
    def find_assets(pattern, to_run)
      data = FileList.new(pattern).map do |path|
        asset = self.class::ASSET.new(path, to_run)
        _ = [asset.label, asset]
      end
      # Remove any asset that we're not interested in.
      data.select { |x| x[1].should_run? }.to_h.reject { |_, v| self.class::EXCLUDE.include?(v.name) }
    end
  end

  # Runner for tests on the admin namespace
  class AdminTestRunner < TestRunner
    HELMFILE_PATH = 'helmfile.d/admin_ng/helmfile.yaml'
    ASSET = AdminAsset
    # We have just one asset here - the admin helmfile.
    def find_assets(_pattern, to_run)
      asset = self.class::ASSET.new(self.class::HELMFILE_PATH, nil)
      asset.filter_fixtures(to_run)
      { 'admin' => asset }
    end
  end

  # Runner for tests on the helmfile deployments
  class DeploymentTestRunner < TestRunner
    ASSET = HelmfileAsset
    DEFAULT_TESTS = %w[lint diff].freeze
    EXCLUDE = ['_example_'].freeze
  end
end