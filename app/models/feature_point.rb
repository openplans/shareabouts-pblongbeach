class FeaturePoint < ActiveRecord::Base
  
  class InRegionValidator < ActiveModel::Validator
    def validate(record)
      record.find_regions[0]
    rescue IndexError
      record.errors[:base] << "Point doesn't fall within the defined regions"
    end
  end
  
  has_many :votes, :as => :supportable, :dependent => :destroy
  has_many :comments, :as => :commentable, :dependent => :destroy, :inverse_of => :commentable
  has_many :feature_regions, :as => :feature, :dependent => :destroy
  has_many :regions, :through => :feature_regions
  
  belongs_to :user
  
  validates :the_geom,  :presence => true
  
  attr_accessor :found_regions
  
  before_create :find_regions
  after_create :add_to_regions
  
  accepts_nested_attributes_for :comments
  
  validates_with InRegionValidator

  def votes_count
    votes.count
  end
  
  def latitude
    return the_geom.y if the_geom
  end

  def longitude
    return the_geom.x if the_geom
  end
  
  def nearest
    self.class.where("id <> #{id}").select("*, the_geom <-> point '#{the_geom}' as distance").order("distance asc").limit(1).first
  end
  
  def as_geo_json
    {
      :type => "Feature", 
      :geometry => {
        :type => "Point", 
        :coordinates => [longitude, latitude]
      },
      :properties => {
        :id             => id,
        :name           => name,
        :description    => description
      }
    }
  end
  
  def find_regions
    @found_regions ||= ActiveRecord::Base.connection.execute( "select * from regions where ST_Contains(the_geom, ST_SetSRID(ST_Point(#{longitude},#{latitude}),4326))")
  end
  
  def add_to_regions
    found_regions.each do |row|
      feature_regions.create :region_id => row["id"].to_i
    end
  end
end