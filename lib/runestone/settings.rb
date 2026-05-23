# frozen_string_literal: true

class Runestone::Settings

  attr_reader :name, :dictionary, :indexes
  
  def initialize(model, name: , dictionary: , &block)
    @name = name
    @dictionary = dictionary
    @indexes = {}
    instance_exec(&block)
  end

  def index(*args, weight: 1)
    @indexes[weight] = args.map(&:to_s)
  end

  def attribute(*names, on: nil, &block)
    if block_given? and names.length > 1
      raise ArgumentError.new('Cannot pass multiple attribute names if block given')
    end
    on = on.to_s if on && !on.is_a?(Proc)

    @attributes ||= {}
    names.each do |name|
      @attributes[name.to_sym] = [block ? block : nil, on]
    end
  end
  alias :attributes :attribute

  def extract_attributes(record)
    attributes = {}

    @attributes.each do |name, value|
      attributes[name] = if value[0].is_a?(Proc)
        record.instance_exec(&value[0])
      else
        record.send(name)
      end
    end

    remove_nulls(attributes)
  end

  def record_changed_for_dependency?(record, name, on)
    case on
    when Proc
      record.instance_exec(&on)
    when String, Symbol
      record.send(on)
    when Array
      dep.detect { |d| record_changed_for_dependency?(record, name, d) }
    else
      if record.attribute_names.include?(name)
        record.changes.has_key?(name)
      elsif association = record.send(:association_instance_get, name.to_sym)
        association && Array.wrap(association.target).any? {|r| r.changed_for_autosave?() }
      else
        ActiveRecord::Base.logger&.warn do 
          color("WARNING", RED, bold: true) +
          " Runestone index "+
          (self.name == "default" ? "\"#{self.name}\" " : '') +
          "on \"#{record.class.name}\" can't determine when to update attribute \"#{name}\", provide \"on:\" option to stop update when unnceessary"
        end
        true
      end
    end
  end
  
  # ANSI sequence modes
  MODES = {
    clear:     0,
    bold:      1,
    italic:    3,
    underline: 4,
  }

  # ANSI sequence colors
  BLACK   = "\e[30m"
  RED     = "\e[31m"
  GREEN   = "\e[32m"
  YELLOW  = "\e[33m"
  BLUE    = "\e[34m"
  MAGENTA = "\e[35m"
  CYAN    = "\e[36m"
  WHITE   = "\e[37m"
  
  def color(text, color, mode_options = {}) # :doc:
    mode = mode_from(mode_options)
    clear = "\e[#{MODES[:clear]}m"
    "#{mode}#{color}#{text}#{clear}"
  end
  
  def mode_from(options)
    modes = MODES.values_at(*options.compact_blank.keys)
    "\e[#{modes.join(";")}m" if modes.any?
  end
  
  def changed?(record)
    @attributes.detect do |name, value|
      record_changed_for_dependency?(record, name.to_s, value[1])
    end
  end
  
  def vectorize(data)
    conn = Runestone::Model.connection
    tsvector = []

    @indexes.each do |weight, paths|
      tsweight = {4 => 'D', 3 => 'C', 2 => 'B', 1 => 'A'}[weight]
      paths.each do |path|
        path = path.to_s.split('.')
        
        dig(data, path).each do |value|
          next if !value
          language = value.to_s.size <= 5 ? 'simple' : @dictionary
          tsvector << "setweight(to_tsvector(#{conn.quote(language)}, #{conn.quote(value.to_s.downcase)}), #{conn.quote(tsweight)})"
        end
      end
    end
    tsvector.empty? ? ["to_tsvector('')"] : tsvector
  end
  
  def corpus(data)
    words = []
    
    @indexes.each do |weight, paths|
      paths.each do |path|
        dig(data, path.to_s.split('.')).each do |value|
          next if !value
          value.to_s.split(/\s+/).each do |word|
            words << word.downcase
          end
        end
      end
    end
    
    words
  end

  def remove_nulls(value)
    if value.is_a?(Hash)
      nh = {}
      value.each do |k, v|
        nh[k] = if v.is_a?(Hash) || v.is_a?(Array)
          remove_nulls(v)
        elsif !v.nil?
          v.is_a?(String) ? v.unicode_normalize(:nfc) : v
        end
        nh.delete(k) if nh[k].nil? || (nh[k].is_a?(Hash) && nh[k].empty?)
      end
      nh
    elsif value.is_a?(Array)
      value.select{|i| !i.nil? && !i.empty? }.map { |i| remove_nulls(i) }
    else
      value
    end
  end

  def dig(data, keys)
    if data.is_a?(Hash)
      key = keys.shift
      dig(data[key.to_sym] || data[key.to_s], keys)
    elsif data.is_a?(Array)
      data.map{ |d| dig(d, keys.dup) }.flatten.compact
    else
      [data]
    end
  end

end