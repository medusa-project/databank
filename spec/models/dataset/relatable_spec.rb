require 'rails_helper'

RSpec.describe Dataset::Relatable do
  let(:dataset) { create(:dataset) }

  describe '#handle_related_materials' do
    it 'separates related, cited, and external non-version relationships' do
      related = create(:related_material,
                       dataset: dataset,
                       datacite_list: [Databank::Relationship::SUPPLEMENT_TO,
                                       Databank::Relationship::CITED_BY].join(', '))
      external = create(:related_material,
                        dataset: dataset,
                        datacite_list: 'IsReferencedBy')
      create(:related_material,
             dataset: dataset,
             datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)

      dataset.handle_related_materials

      expect(dataset.materials_related).to contain_exactly(related)
      expect(dataset.materials_cited_by).to contain_exactly(related)
      expect(dataset.num_external_relationships).to eq(2)
      expect(dataset.materials_related).not_to include(external)
    end

    it 'clears relationship collections when there are no related materials' do
      dataset.handle_related_materials

      expect(dataset.materials_related).to eq([])
      expect(dataset.materials_cited_by).to eq([])
      expect(dataset.num_external_relationships).to eq(0)
    end
  end

  describe '#nonversion_related_materials' do
    it 'returns only materials with non-version relationships' do
      nonversion = create(:related_material,
                          dataset: dataset,
                          datacite_list: Databank::Relationship::SUPPLEMENTED_BY)
      create(:related_material,
             dataset: dataset,
             datacite_list: Databank::Relationship::NEW_VERSION_OF)

      expect(dataset.nonversion_related_materials).to contain_exactly(nonversion)
    end

    it 'returns an empty array when all materials are version-only' do
      create(:related_material,
             dataset: dataset,
             datacite_list: Databank::Relationship::PREVIOUS_VERSION_OF)

      expect(dataset.nonversion_related_materials).to eq([])
    end
  end

  describe '#invalid_material' do
    it 'returns true when both link and citation are blank' do
      expect(dataset.invalid_material('link' => '', 'citation' => '')).to be true
    end

    it 'returns false when link is present' do
      expect(dataset.invalid_material('link' => 'https://example.org', 'citation' => '')).to be false
    end

    it 'returns false when citation is present' do
      expect(dataset.invalid_material('link' => '', 'citation' => 'Example citation')).to be false
    end
  end
end