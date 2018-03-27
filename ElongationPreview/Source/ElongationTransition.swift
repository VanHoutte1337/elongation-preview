//
//  ElongationTransition.swift
//  ElongationPreview
//
//  Created by Abdurahim Jauzee on 11/02/2017.
//  Copyright © 2017 Ramotion. All rights reserved.
//

import UIKit

/// Provides transition animations between `ElongationViewController` & `ElongationDetailViewController`.
public class ElongationTransition: NSObject {

    // MARK: Constructor

    internal convenience init(presenting: Bool) {
        self.init()
        self.presenting = presenting
    }

    // MARK: Properties

    fileprivate var presenting = true
    fileprivate var appearance: ElongationConfig { return ElongationConfig.shared }

    fileprivate let additionalOffsetY: CGFloat = 30

    fileprivate var rootKey: UITransitionContextViewControllerKey {
        return presenting ? .from : .to
    }
    fileprivate var detailKey: UITransitionContextViewControllerKey {
        return presenting ? .to : .from
    }
    fileprivate var rootViewKey: UITransitionContextViewKey {
        return presenting ? .from : .to
    }
    fileprivate var detailViewKey: UITransitionContextViewKey {
        return presenting ? .to : .from
    }

    fileprivate func root(from context: UIViewControllerContextTransitioning) -> ElongationViewController {
        let viewController = context.viewController(forKey: rootKey)

        if let navi = viewController as? UINavigationController {
            for case let elongationViewController as ElongationViewController in navi.viewControllers {
                return elongationViewController
            }
        } else if let tab = viewController as? UITabBarController, let elongationViewController = tab.selectedViewController as? ElongationViewController {
            return elongationViewController
        } else if let elongationViewController = viewController as? ElongationViewController {
            return elongationViewController
        }

        fatalError("Can't get `ElongationViewController` from UINavigationController nor from context's viewController itself.")
    }

    fileprivate func detail(from context: UIViewControllerContextTransitioning) -> ElongationDetailViewController {
        return context.viewController(forKey: detailKey) as? ElongationDetailViewController ?? ElongationDetailViewController(nibName: nil, bundle: nil)
    }
}

// MARK: - Transition Protocol Implementation

extension ElongationTransition: UIViewControllerAnimatedTransitioning {

    /// :nodoc:
    open func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        return presenting ? appearance.detailPresentingDuration : appearance.detailDismissingDuration
    }

    /// :nodoc:
    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        presenting ? present(using: transitionContext) : dismiss(using: transitionContext)
    }
}

// MARK: - Presenting Animation

extension ElongationTransition {

    fileprivate func present(using context: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: context)
        let containerView = context.containerView
        containerView.backgroundColor = appearance.containerViewBackgroundColor
        let root = self.root(from: context) // ElongationViewController
        let detail = self.detail(from: context) // ElongationDetailViewController
        let rootView = context.view(forKey: rootViewKey)
        let detailView = context.view(forKey: detailViewKey)

        var detailViewFinalFrame = context.finalFrame(for: detail) // Final frame for presenting view controller
        let statusBarHeight: CGFloat
        if #available(iOS 11, *) {
            statusBarHeight = UIApplication.shared.statusBarFrame.height
        } else {
            statusBarHeight = 0
        }

        guard
            let rootTableView = root.tableView, // get `tableView` from root
            let path = root.expandedIndexPath ?? rootTableView.indexPathForSelectedRow, // get expanded or selected indexPath
            let cell = rootTableView.cellForRow(at: path) as? ElongationCell, // get expanded cell from root `tableView`
            let view = detailView // unwrap optional `detailView`
        else { return }

        // Determine are `root` view is in expanded state.
        // We need to know that because animation depends on the state.
//        let isExpanded = root.state == .expanded

        // Create `ElongationHeader` from `ElongationCell` and set it as `headerView` to `detail` view controller
        let header = cell.elongationHeader
        detail.headerView = header

        // Get frame of expanded cell and convert it to `containerView` coordinates
        let rect = rootTableView.rectForRow(at: path)
        let cellFrame = rootTableView.convert(rect, to: containerView)

        // Whole view snapshot
//        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
        view.drawHierarchy(in: CGRect(x: 0, y: -statusBarHeight, width: view.bounds.width, height: view.bounds.height), afterScreenUpdates: true)
        let fullImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        // Header snapshot
        UIGraphicsBeginImageContextWithOptions(header.frame.size, true, 0)
        fullImage.draw(at: CGPoint(x: 0, y: 0))
        let headerSnapsot = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        // TableView snapshot
        let cellsSize = CGSize(width: view.frame.width, height: view.frame.height - header.frame.height)
        UIGraphicsBeginImageContextWithOptions(cellsSize, true, 0)
        fullImage.draw(at: CGPoint(x: 0, y: -header.frame.height))
        let tableSnapshot = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        let headerSnapshotView = UIImageView(image: headerSnapsot)
        let tableViewSnapshotView = UIImageView(image: tableSnapshot)

        let tempView = UIView()
        tempView.backgroundColor = header.bottomView.backgroundColor
        
        view.frame.origin.y = view.frame.origin.y - statusBarHeight
        
        // Add coming `view` to temporary `containerView`
        containerView.addSubview(view)
        containerView.addSubview(tempView)
        containerView.addSubview(tableViewSnapshotView)

        // Update `bottomView`s top constraint and invalidate layout
        header.bottomViewTopConstraint.constant = appearance.topViewHeight
        header.bottomView.setNeedsLayout()

//        var height = isExpanded ? cellFrame.height : appearance.topViewHeight + appearance.bottomViewHeight
//        height = cellFrame.height
        
        view.frame = CGRect(x: 0, y: cellFrame.minY, width: detailViewFinalFrame.width, height: cellFrame.height)
        tableViewSnapshotView.backgroundColor = .red
        tableViewSnapshotView.frame = CGRect(x: 0, y: detailViewFinalFrame.maxY, width: cellsSize.width, height: cellsSize.height)
        tempView.frame = CGRect(x: 0, y: cellFrame.maxY - statusBarHeight, width: detailViewFinalFrame.width, height: 0)
        root.view?.alpha = 1
        
        // enable this line if you want to hide the bar between the table and the statusbar
//        detailViewFinalFrame.origin.y = detailViewFinalFrame.origin.y + statusBarHeight

        // Animate to new state
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {

            header.scalableView.transform = .identity // reset scale to 1.0
            header.contentView.frame = CGRect(x: 0, y: 0, width: cellFrame.width, height: cellFrame.height + self.appearance.bottomViewOffset)

            header.contentView.setNeedsLayout()
            header.contentView.layoutIfNeeded()
            
            view.frame = detailViewFinalFrame
//            headerSnapshotView.frame = CGRect(x: 0, y: 0, width: cellFrame.width, height: height)
            tableViewSnapshotView.frame = CGRect(x: 0, y: header.frame.height + statusBarHeight, width: detailViewFinalFrame.width, height: cellsSize.height)
            tempView.frame = CGRect(x: 0, y: headerSnapshotView.frame.maxY, width: detailViewFinalFrame.width, height: detailViewFinalFrame.height)
        }) { completed in
            rootView?.removeFromSuperview()
            tempView.removeFromSuperview()
//            headerSnapshotView.removeFromSuperview()
            tableViewSnapshotView.removeFromSuperview()
            context.completeTransition(completed)
        }
    }
}

// MARK: - Dismiss Animation

extension ElongationTransition {

    fileprivate func dismiss(using context: UIViewControllerContextTransitioning) {
        let root = self.root(from: context)
        let detail = self.detail(from: context)
        let containerView = context.containerView
        containerView.backgroundColor = appearance.containerViewBackgroundColor
        let duration = transitionDuration(using: context)

        guard
            let header = detail.headerView,
            let view = context.view(forKey: detailViewKey), // actual view of `detail` view controller
            let rootTableView = root.tableView, // `tableView` of root view controller
            let detailTableView = detail.tableView, // `tableView` of detail view controller
            let path = root.expandedIndexPath ?? rootTableView.indexPathForSelectedRow, // `indexPath` of expanded or selected cell
            let expandedCell = rootTableView.cellForRow(at: path) as? ElongationCell
        else { return }

        // Collapse root view controller without animation
        root.collapseCells(animated: false)
        expandedCell.topViewTopConstraint.constant = 0
        expandedCell.topViewHeightConstraint.constant = appearance.topViewHeight
        expandedCell.hideSeparator(false, animated: true)
        expandedCell.topView.setNeedsLayout()

        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        // the offset is equal to the statusbarframe height
        let yOffset: CGFloat
        if #available(iOS 11, *) {
            yOffset = UIApplication.shared.statusBarFrame.height
        } else {
            yOffset = 0
        }
        
        // calculate the rectangle for the top view
        let topViewSize = CGRect(origin: CGPoint.zero, size: CGSize(width: view.bounds.width, height: appearance.topViewHeight))
        UIGraphicsBeginImageContextWithOptions(topViewSize.size, false, 0)
        header.topView.drawHierarchy(in: CGRect(origin: CGPoint.zero, size: CGSize(width: view.bounds.width, height: topViewSize.height)), afterScreenUpdates: true)
        let topViewImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let topViewImageView = UIImageView(image: topViewImage)
        
        // calculate the rectangle for the bottom view
        let bottomViewSize = CGSize(width: view.bounds.width, height: appearance.bottomViewHeight)
        UIGraphicsBeginImageContextWithOptions(bottomViewSize, false, 0)
        header.bottomView.drawHierarchy(in: CGRect(origin: CGPoint.zero, size: bottomViewSize), afterScreenUpdates: true)
        let bottomViewImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let bottomViewImageView = UIImageView(image: bottomViewImage)
        
        // calculate the rectangle for the detail view (take the full container - offset - topview - bottomview)
        let detailViewsize = CGSize(width: view.bounds.width, height: containerView.frame.height + yOffset - topViewSize.height - bottomViewSize.height)
        UIGraphicsBeginImageContextWithOptions(detailViewsize, false, 0)
        image.draw(at: CGPoint(x: 0, y: -header.frame.height))
        let tableViewImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let tableViewSnapshotView = UIImageView(image: tableViewImage)
        
        // we create a invisible subcontainer that has the size of the tableview and will contain it
        let subContainerView = UIView(frame: tableViewSnapshotView.frame)
        subContainerView.addSubview(tableViewSnapshotView)
        // this allows us to clip everything that moves over the bounds
        // this allows us to move the tableview top the top, but it wil look like it disappears in the original cell
        subContainerView.clipsToBounds = true
        // we need to set the Y coordinate equal to the top offset + the height of the top view + the height of the bottom view
        subContainerView.frame.origin.y = yOffset + topViewSize.height + bottomViewSize.height
        
        // Add `header` and `tableView` snapshot to temporary container
        containerView.addSubview(subContainerView)
        containerView.addSubview(bottomViewImageView)
        containerView.addSubview(topViewImageView)

        // Prepare view to dismissing
        let rect = rootTableView.rectForRow(at: path)
        let cellFrame = rootTableView.convert(rect, to: containerView)
        // hide the detail view before we start the animation
        detailTableView.alpha = 0
        // we set alpha of the root view controller back to 1 before we start the animation
        root.view?.alpha = 1

        // the starting point of the topview is the offset value
        topViewImageView.frame.origin.y = yOffset
        // the startingpoint is the yoffset value + height of the topview
        bottomViewImageView.frame = CGRect(x: 0, y: topViewImageView.frame.origin.y + topViewSize.height, width: view.bounds.width, height: bottomViewSize.height)
        // NOTE: no need to change the frame position of the tableview because we want to use the same location
        
        // we will change the frame of the subviews so that they collapse
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
            // Animate views to collapsed cell size
            let collapsedFrame = CGRect(x: 0, y: cellFrame.origin.y, width: header.frame.width, height: cellFrame.height)
            topViewImageView.frame = collapsedFrame
            bottomViewImageView.frame = collapsedFrame
            // we will adjust the y coordinate to a negative table view height, this will move
            // the table top the original cell and above
            tableViewSnapshotView.frame.origin.y = -tableViewSnapshotView.frame.height
            // the y coordinate should be at the bottom of the original cell
            subContainerView.frame.origin.y = cellFrame.origin.y + cellFrame.height
            expandedCell.contentView.layoutIfNeeded()
        }, completion: { completed in
            root.state = .normal
            root.expandedIndexPath = nil
            view.removeFromSuperview()
            context.completeTransition(completed)
        })
    }
}
