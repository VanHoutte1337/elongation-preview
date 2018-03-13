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
        containerView.backgroundColor = .white
        let root = self.root(from: context) // ElongationViewController
        let detail = self.detail(from: context) // ElongationDetailViewController
        let rootView = context.view(forKey: rootViewKey)
        let detailView = context.view(forKey: detailViewKey)

        let detailViewFinalFrame = context.finalFrame(for: detail) // Final frame for presenting view controller
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
        let isExpanded = root.state == .expanded

        // Create `ElongationHeader` from `ElongationCell` and set it as `headerView` to `detail` view controller
        let header = cell.elongationHeader
        detail.headerView = header

        // Get frame of expanded cell and convert it to `containerView` coordinates
        let rect = rootTableView.rectForRow(at: path)
        let cellFrame = rootTableView.convert(rect, to: containerView)

        // Whole view snapshot
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
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
        fullImage.draw(at: CGPoint(x: 0, y: -header.frame.height - statusBarHeight))
        let tableSnapshot = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        let headerSnapshotView = UIImageView(image: headerSnapsot)
        let tableViewSnapshotView = UIImageView(image: tableSnapshot)

        let tempView = UIView()
        tempView.backgroundColor = header.bottomView.backgroundColor

        // Add coming `view` to temporary `containerView`
        containerView.addSubview(view)
        containerView.addSubview(tempView)
        containerView.addSubview(tableViewSnapshotView)

        // Update `bottomView`s top constraint and invalidate layout
        header.bottomViewTopConstraint.constant = appearance.topViewHeight
        header.bottomView.setNeedsLayout()

        let height = isExpanded ? cellFrame.height : appearance.topViewHeight + appearance.bottomViewHeight

        view.frame = CGRect(x: 0, y: cellFrame.minY - statusBarHeight, width: detailViewFinalFrame.width, height: cellFrame.height)
        headerSnapshotView.frame = CGRect(x: 0, y: cellFrame.minY - statusBarHeight, width: cellFrame.width, height: height)
        tableViewSnapshotView.frame = CGRect(x: 0, y: detailViewFinalFrame.maxY, width: cellsSize.width, height: cellsSize.height)
        tempView.frame = CGRect(x: 0, y: cellFrame.maxY - statusBarHeight, width: detailViewFinalFrame.width, height: 0)

        // Animate to new state
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
            root.view?.alpha = 0

            header.scalableView.transform = .identity // reset scale to 1.0
            header.contentView.frame = CGRect(x: 0, y: 0, width: cellFrame.width, height: cellFrame.height + self.appearance.bottomViewOffset)

            header.contentView.setNeedsLayout()
            header.contentView.layoutIfNeeded()

            view.frame = detailViewFinalFrame
            headerSnapshotView.frame = CGRect(x: 0, y: 0, width: cellFrame.width, height: height)
            tableViewSnapshotView.frame = CGRect(x: 0, y: header.frame.height + statusBarHeight, width: detailViewFinalFrame.width, height: cellsSize.height)
            tempView.frame = CGRect(x: 0, y: headerSnapshotView.frame.maxY, width: detailViewFinalFrame.width, height: detailViewFinalFrame.height)
        }) { completed in
            rootView?.removeFromSuperview()
            tempView.removeFromSuperview()
            headerSnapshotView.removeFromSuperview()
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
        
        // the offset of the table compared to the top point of the view
        let yOffset = detailTableView.contentOffset.y
        
        // calculate the rectangle for the top view
        let topViewSize = CGRect(origin: CGPoint.zero, size: CGSize(width: view.bounds.width, height: appearance.topViewHeight))
        UIGraphicsBeginImageContextWithOptions(topViewSize.size, false, 0)
        header.topView.drawHierarchy(in: CGRect(origin: CGPoint.zero, size: CGSize(width: view.bounds.width, height: topViewSize.height)), afterScreenUpdates: true)
        let topViewImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let topViewImageView = UIImageView(image: topViewImage)

        // add the view height - header height (tableViewHeight) so that we can add it to the subview
        //        UIGraphicsBeginImageContextWithOptions(CGSize(width: view.bounds.width, height: topViewSize.height + (view.bounds.height - header.frame.height)), false, 0)
        //        UIGraphicsBeginImageContextWithOptions(CGSize(width: view.bounds.width, height: containerView.frame.height + yOffset), false, 0)
        

        
        
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
        
        

        // Add `header` and `tableView` snapshot to temporary container
        containerView.addSubview(tableViewSnapshotView)
        containerView.addSubview(bottomViewImageView)
        containerView.addSubview(topViewImageView)
        
//        // we create a subcontainer, that will take the space below the topviewimageview. we will than add the tableViewSnapshotView to it
//        let subContainerTopViewImageView = UIView(frame: CGRect(x: 0, y: topViewSize.height, width: view.bounds.width, height: tableViewSnapshotView.frame.height))
//        // we set the clipstobounds to true so that when the tableViewSnapshotView slides to the top, it will not be shown out of the bounds
//        // which creates a upward sliding animation, instead of scaling the image
//        subContainerTopViewImageView.clipsToBounds = true
//        subContainerTopViewImageView.addSubview(tableViewSnapshotView)
        
        // add tableview to the top view, so we can have a slide in animation
//        topViewImageView.addSubview(subContainerTopViewImageView)
        
        topViewImageView.clipsToBounds = true

        // Prepare view to dismissing
        let rect = rootTableView.rectForRow(at: path)
        let cellFrame = rootTableView.convert(rect, to: containerView)
        detailTableView.alpha = 0

        // Place views at their start points.
//        topViewImageView.frame = CGRect(x: 0, y: -yOffset, width: topViewSize.width, height: topViewSize.height + (view.bounds.height - header.frame.height))
        
        // the starting point of the topview is the offset value
        topViewImageView.frame.origin.y = -yOffset
        // the startingpoint is the yoffset value + height of the topview
        bottomViewImageView.frame = CGRect(x: 0, y: topViewImageView.frame.origin.y + topViewSize.height, width: view.bounds.width, height: bottomViewSize.height)
        //
        tableViewSnapshotView.frame = CGRect(x: 0, y: bottomViewImageView.frame.origin.y + bottomViewSize.height, width: view.bounds.width, height: detailViewsize.height)

        // we will change the frame of the subviews so that they collapse
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
            root.view?.alpha = 1
            tableViewSnapshotView.alpha = 1

            // Animate views to collapsed cell size
            let collapsedFrame = CGRect(x: 0, y: cellFrame.origin.y, width: header.frame.width, height: cellFrame.height)
            topViewImageView.frame = collapsedFrame
            bottomViewImageView.frame = collapsedFrame
            tableViewSnapshotView.frame = collapsedFrame
            expandedCell.contentView.layoutIfNeeded()
        }, completion: { completed in
            root.state = .normal
            root.expandedIndexPath = nil
            view.removeFromSuperview()
            context.completeTransition(completed)
        })
    }
}
