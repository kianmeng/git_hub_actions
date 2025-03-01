defmodule GitHubActions.WorkflowTest do
  use ExUnit.Case

  import Prove

  alias GitHubActions.Config
  alias GitHubActions.Workflow

  setup do
    Config.read("priv/config.exs")
  end

  describe "eval/1" do
    prove "simple workflow",
          Workflow.eval("test/fixtures/workflow_simple.exs") ==
            {:ok, [name: "CI"]}

    prove "workflow with jobs",
          Workflow.eval("test/fixtures/workflow_jobs.exs") ==
            {:ok,
             [
               name: "CI",
               env: [GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}"],
               jobs: [
                 linux: [
                   name: """
                   Test on Ubuntu \
                   (Elixir ${{ matrix.elixir }}, \
                   OTP ${{ matrix.otp }})\
                   """,
                   "runs-on": "ubuntu-latest"
                 ]
               ]
             ]}

    prove "workflow matrix",
          Workflow.eval("test/fixtures/workflow_matrix.exs") ==
            {:ok,
             [
               name: "CI",
               env: [GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}"],
               jobs: [
                 linux: [
                   name: "Test on Ubuntu (Elixir ${{ matrix.elixir }}, OTP ${{ matrix.otp }})",
                   "runs-on": "ubuntu-latest",
                   strategy: [
                     matrix: [
                       elixir: ["1.10.4", "1.11.4", "1.12.3", "1.13.3"],
                       otp: ["21.3", "22.3", "23.3", "24.2"],
                       exclude: [
                         [elixir: "1.10.4", otp: "24.2"],
                         [elixir: "1.12.3", otp: "21.3"],
                         [elixir: "1.13.3", otp: "21.3"]
                       ]
                     ]
                   ]
                 ]
               ]
             ]}

    prove "workflow steps",
          Workflow.eval("test/fixtures/workflow_steps.exs") ==
            {:ok,
             [
               name: "CI",
               env: [GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}"],
               jobs: [
                 linux: [
                   name: """
                   Test on Ubuntu (\
                   Elixir ${{ matrix.elixir }}, \
                   OTP ${{ matrix.otp }})\
                   """,
                   "runs-on": "ubuntu-latest",
                   steps: [
                     [name: "Checkout", uses: "actions/checkout@v2"]
                   ]
                 ]
               ]
             ]}

    prove "default workflow",
          Workflow.eval("priv/default.exs") ==
            {:ok,
             [
               name: "CI",
               env: [GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}"],
               on: ["pull_request", "push"],
               jobs: [
                 linux: [
                   name: """
                   Test on Ubuntu (\
                   Elixir ${{ matrix.elixir }}, \
                   OTP ${{ matrix.otp }})\
                   """,
                   "runs-on": "ubuntu-latest",
                   strategy: [
                     matrix: [
                       elixir: ["1.11.4", "1.12.3", "1.13.3"],
                       otp: ["21.3", "22.3", "23.3", "24.2"],
                       exclude: [
                         [elixir: "1.12.3", otp: "21.3"],
                         [elixir: "1.13.3", otp: "21.3"]
                       ]
                     ]
                   ],
                   steps: [
                     [
                       name: "Checkout",
                       uses: "actions/checkout@v2"
                     ],
                     [
                       name: "Setup Elixir",
                       uses: "erlef/setup-beam@v1",
                       with: [
                         "elixir-version": "${{ matrix.elixir }}",
                         "otp-version": "${{ matrix.otp }}"
                       ]
                     ],
                     [
                       name: "Restore deps",
                       uses: "actions/cache@v2",
                       with: [
                         path: "deps",
                         key: """
                         deps-\
                         ${{ runner.os }}-\
                         ${{ matrix.elixir }}-\
                         ${{ matrix.otp }}-\
                         ${{ hashFiles(format('{0}{1}', github.workspace, '/mix.lock')) }}\
                         """
                       ]
                     ],
                     [
                       name: "Restore _build",
                       uses: "actions/cache@v2",
                       with: [
                         path: "_build",
                         key: """
                         _build-\
                         ${{ runner.os }}-\
                         ${{ matrix.elixir }}-\
                         ${{ matrix.otp }}-\
                         ${{ hashFiles(format('{0}{1}', github.workspace, '/mix.lock')) }}\
                         """
                       ]
                     ],
                     [
                       name: "Restore test/support/plts",
                       uses: "actions/cache@v2",
                       with: [
                         path: "test/support/plts",
                         key: """
                         test/support/plts-\
                         ${{ runner.os }}-\
                         ${{ matrix.elixir }}-\
                         ${{ matrix.otp }}-\
                         ${{ hashFiles(format('{0}{1}', github.workspace, '/mix.lock')) }}\
                         """
                       ]
                     ],
                     [
                       name: "Get dependencies",
                       run: "mix deps.get"
                     ],
                     [
                       name: "Compile dependencies",
                       run: "MIX_ENV=test mix deps.compile"
                     ],
                     [
                       name: "Compile project",
                       run: "MIX_ENV=test mix compile --warnings-as-errors"
                     ],
                     [
                       name: "Check code format",
                       if:
                         "${{ contains(matrix.elixir, '1.13.3') && contains(matrix.otp, '24.2') }}",
                       run: "MIX_ENV=test mix format --check-formatted"
                     ],
                     [
                       name: "Lint code",
                       if:
                         "${{ contains(matrix.elixir, '1.13.3') && contains(matrix.otp, '24.2') }}",
                       run: "MIX_ENV=test mix credo --strict"
                     ],
                     [
                       {:name, "Run tests"},
                       {:run, "MIX_ENV=test mix test"},
                       {:if,
                        "${{ !(contains(matrix.elixir, '1.13.3') && contains(matrix.otp, '24.2')) }}"}
                     ],
                     [
                       name: "Run tests with coverage",
                       run: "MIX_ENV=test mix coveralls.github",
                       if:
                         "${{ contains(matrix.elixir, '1.13.3') && contains(matrix.otp, '24.2') }}"
                     ],
                     [
                       name: "Static code analysis",
                       run: "mix dialyzer"
                     ]
                   ]
                 ]
               ]
             ]}
  end
end
