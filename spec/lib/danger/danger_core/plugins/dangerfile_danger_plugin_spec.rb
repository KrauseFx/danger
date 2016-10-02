require "danger/danger_core/environment_manager"
require "danger/danger_core/plugins/dangerfile_danger_plugin"

RSpec.describe Danger::Dangerfile::DSL, host: :github do
  let(:dm) { testing_dangerfile }

  describe "#import" do
    describe "#import_local" do
      it "supports exact paths" do
        dm.danger.import_plugin("spec/fixtures/plugins/example_exact_path.rb")

        expect { dm.example_exact_path }.to_not raise_error
        expect(dm.example_exact_path.echo).to eq("Hi there exact")
      end

      it "supports file globbing" do
        dm.danger.import_plugin("spec/fixtures/plugins/*globbing*.rb")

        expect(dm.example_globbing.echo).to eq("Hi there globbing")
      end

      it "not raises an error when calling a plugin that's a subclass of Plugin" do
        expect do
          dm.danger.import_plugin("spec/fixtures/plugins/example_not_broken.rb")
        end.not_to raise_error
      end

      it "raises an error when calling a plugin that's not a subclass of Plugin" do
        expect do
          dm.danger.import_plugin("spec/fixtures/plugins/example_broken.rb")
        end.to raise_error(RuntimeError, %r{spec/fixtures/plugins/example_broken.rb doesn't contain any valid danger plugin})
      end
    end

    describe "#import_url" do
      it "downloads a remote .rb file" do
        expect { dm.example_ping.echo }.to raise_error NoMethodError

        url = "https://krausefx.com/example_remote.rb"
        stub_request(:get, "https://krausefx.com/example_remote.rb").
          to_return(status: 200, body: File.read("spec/fixtures/plugins/example_echo_plugin.rb"))

        dm.danger.import_plugin(url)

        expect(dm.example_ping.echo).to eq("Hi there 🎉")
      end

      it "rejects unencrypted plugins" do
        expect do
          dm.danger.import_plugin("http://unencrypted.org")
        end.to raise_error("URL is not https, for security reasons `danger` only supports encrypted requests")
      end
    end
  end

  describe "#import_dangerfile" do
    it "defaults to org/repo and warns of deprecation" do
      outer_dangerfile = "danger.import_dangerfile('example/example')"
      inner_dangerfile = "message('OK')"

      url = "https://raw.githubusercontent.com/example/example/master/Dangerfile"
      stub_request(:get, url).to_return(status: 200, body: inner_dangerfile)

      dm.parse(Pathname.new("."), outer_dangerfile)
      expect(dm.status_report[:warnings]).to eq(["Use `import_dangerfile(github: 'example/example')` instead of `import_dangerfile 'example/example'`."])
      expect(dm.status_report[:messages]).to eq(["OK"])
    end

    it "github: 'repo/name'" do
      outer_dangerfile = "danger.import_dangerfile(github: 'example/example')"
      inner_dangerfile = "message('OK')"

      url = "https://raw.githubusercontent.com/example/example/master/Dangerfile"
      stub_request(:get, url).to_return(status: 200, body: inner_dangerfile)

      dm.parse(Pathname.new("."), outer_dangerfile)
      expect(dm.status_report[:messages]).to eq(["OK"])
    end

    it "github: 'repo/name', branch: 'custom-branch', path: 'path/to/Dangefile'" do
      outer_dangerfile = "danger.import_dangerfile(github: 'example/example', branch: 'custom-branch', path: 'path/to/Dangefile')"
      inner_dangerfile = "message('OK')"

      url = "https://raw.githubusercontent.com/example/example/custom-branch/path/to/Dangefile"
      stub_request(:get, url).to_return(status: 200, body: inner_dangerfile)

      dm.parse(Pathname.new("."), outer_dangerfile)
      expect(dm.status_report[:messages]).to eq(["OK"])
    end

    it "gitlab: 'repo/name'" do
      outer_dangerfile = "danger.import_dangerfile(gitlab: 'example/example')"
      inner_dangerfile = "message('OK')"

      url = "https://raw.githubusercontent.com/example/example/master/Dangerfile"
      stub_request(:get, url).to_return(status: 200, body: inner_dangerfile)

      dm.parse(Pathname.new("."), outer_dangerfile)
      expect(dm.status_report[:messages]).to eq(["OK"])
    end

    it "gitlab: 'repo/name', branch: 'custom-branch', path: 'path/to/Dangefile'" do
      outer_dangerfile = "danger.import_dangerfile(gitlab: 'example/example', branch: 'custom-branch', path: 'path/to/Dangerfile')"
      inner_dangerfile = "message('OK')"

      url = "https://raw.githubusercontent.com/example/example/custom-branch/path/to/Dangerfile"
      stub_request(:get, url).to_return(status: 200, body: inner_dangerfile)

      dm.parse(Pathname.new("."), outer_dangerfile)
      expect(dm.status_report[:messages]).to eq(["OK"])
    end

    it "path: 'path'" do
      outer_dangerfile = "danger.import_dangerfile(path: 'foo/bar')"
      inner_dangerfile = "message('OK')"

      expect(File).to receive(:open).with(Pathname.new("foo/bar/Dangerfile"), "r:utf-8").and_return(inner_dangerfile)
      dm.parse(Pathname.new("."), outer_dangerfile)
      expect(dm.status_report[:messages]).to eq(["OK"])
    end

    it "gem: 'name'" do
      outer_dangerfile = "danger.import_dangerfile(gem: 'example')"
      inner_dangerfile = "message('OK')"

      expect(File).to receive(:open).with(Pathname.new("/gems/foo/bar/Dangerfile"), "r:utf-8").and_return(inner_dangerfile)
      expect(Gem::Specification).to receive_message_chain(:find_by_name, :gem_dir).and_return("/gems/foo/bar")

      dm.parse(Pathname.new("."), outer_dangerfile)
      expect(dm.status_report[:messages]).to eq(["OK"])
    end
  end

  describe "#scm_provider" do
    context "GitHub", host: :github do
      it "is `:github`" do
        with_git_repo(origin: "git@github.com:artsy/eigen") do
          expect(dm.danger.scm_provider).to eq(:github)
        end
      end
    end

    context "GitLab", host: :gitlab do
      it "is `:gitlab`" do
        with_git_repo(origin: "git@gitlab.com:k0nserv/danger-test.git") do
          expect(dm.danger.scm_provider).to eq(:gitlab)
        end
      end
    end

    context "Bitbucket Server", host: :bitbucket_server do
      it "is `:bitbucket_server`" do
        with_git_repo(origin: "git@stash.example.com:artsy/eigen") do
          expect(dm.danger.scm_provider).to eq(:bitbucket_server)
        end
      end
    end
  end
end
