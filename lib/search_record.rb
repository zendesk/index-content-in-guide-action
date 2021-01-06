class SearchRecord
  attr_reader :id, :external_id, :title, :body, :url

  def initialize(attrs)
    attrs.each do |key, value|
      instance_variable_set("@" + key, value)
    end
  end
end
