# frozen_string_literal: true

describe Graphlyte::Selector do
  context 'manipulating queries' do
    let(:query) do
      Graphlyte.parse(<<~GQL)
        query ($projectPath: ID!, $commitSha: String) {
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
      editor = described_class.new
                              .at('project.pipelines.nodes.status', &:remove)
                              .at('project.pipelines.nodes') do |node|
        node.append do
          downstream do
            nodes { active }
          end
        end
      end

      expect(editor.edit(query)).to produce_equivalent_document(<<~STRING)
        query ($projectPath: ID!, $commitSha: String) {
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
