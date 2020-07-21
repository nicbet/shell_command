class Hash
  def transform_keys
    result = {}
    each_key do |key|
      result[yield(key)] = self[key]
    end
    result
  end

  def stringify_keys
    transform_keys(&:to_s)
  end
end
