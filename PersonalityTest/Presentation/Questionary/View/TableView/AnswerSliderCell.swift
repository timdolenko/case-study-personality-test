import UIKit
import SnapKit

public class AnswerSliderCell: UITableViewCell {
    
    public struct RangeValue {
        var current: Int
        var from: Int
        var to: Int
    }
    
    class var height: CGFloat { 92.0 }
    
    private weak var titleLbl: UILabel!
    private weak var slider: UISlider!
    
    public var didChangeValue: ((Int) -> ())?
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .elevatedDarkBackground
        
        let label = UILabel()
        label.font = .avenirOfSize(16)
        label.textColor = .textLightColor
        label.textAlignment = .center
        addSubview(label)
        
        label.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(22)
        }
        
        let slider = UISlider()
        slider.tintColor = .accentColor
        slider.addTarget(self, action: #selector(didChangeValue(_:)), for: .valueChanged)
        addSubview(slider)
        
        slider.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview()
            make.height.equalTo(44)
        }
        
        self.titleLbl = label
        self.slider = slider
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public func configure(with value: RangeValue) {
        titleLbl.text = String(value.current)
        
        slider.minimumValue = Float(value.from)
        slider.maximumValue = Float(value.to)
        slider.value = Float(value.current)
    }
    
    public func setOption(value: Int) {
        slider.value = Float(value)
    }
    
    @objc func didChangeValue(_ sender: UIButton) {
        let value = Int(slider.value)
        titleLbl.text = String(value)
        didChangeValue?(value)
    }
}

// MARK:  Class Identifiable
extension AnswerSliderCell: ClassIdentifiable {}
