describe Graphlyte::Selector do
  context 'manipulating queries' do
    let(:query) do
      Graphlyte.parse(<<~GQL)
        query name($projectPath: ID!, $commitSha: String) {
          project(fullPath: $projectPath, sha: $commitSha) {
            createdAt
            pipelines(sha: $commitSha) {
              nodes {
                status
                foobar
              }
            }
          }
        }
      GQL
    end

    it 'adds and removes fields' do
      query.at('project.pipelines.nodes') do |pipeline|
        remove :status
        downstream do
          nodes do
            active
          end
        end
      end

      expect(query.to_s).to eql(<<~STRING)
        {
          project(fullPath: $projectPath, sha: $commitSha) {
            createdAt
            pipelines(sha: $commitSha) {
              nodes {
                foobar
                downstream {
                  nodes {
                    active
                  }
                }
              }
            }
          }
        }
      STRING
    end
  end
end