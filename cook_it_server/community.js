const express = require('express');
const { authMiddleware } = require('./auth');
const multer = require('multer');
const admin = require('firebase-admin');

const router = express.Router();

// 이미지 업로드를 위한 multer 설정
const storage = multer.memoryStorage();
const upload = multer({
    storage: storage,
    limits: { fileSize: 10 * 1024 * 1024 } // 10MB 제한
});

// 커뮤니티 게시물 작성 라우트 (인덱스 기반으로 수정)
router.post('/community/post', authMiddleware, upload.single('image'), async (req, res) => {
    try {
        const { recipeIndex, content, title } = req.body;
        const userId = req.user.uid;
        const image = req.file;

        // 필수 필드 검증
        if (recipeIndex === undefined || !content || !title) {
            return res.status(400).json({
                success: false,
                error: '레시피 인덱스, 내용, 제목이 모두 필요합니다.'
            });
        }

        const db = admin.firestore();

        // 사용자 정보 가져오기
        const userDoc = await db.collection('user').doc(userId).get();
        if (!userDoc.exists) {
            return res.status(404).json({
                success: false,
                error: '사용자 정보를 찾을 수 없습니다.'
            });
        }

        // 저장된 레시피 확인 (인덱스로 접근)
        const userData = userDoc.data();
        const savedRecipes = userData.savedRecipes || [];
        const recipeIdx = parseInt(recipeIndex);

        if (isNaN(recipeIdx) || recipeIdx < 0 || recipeIdx >= savedRecipes.length) {
            return res.status(400).json({
                success: false,
                error: '유효하지 않은 레시피 인덱스입니다.'
            });
        }

        const recipeToShare = savedRecipes[recipeIdx];

        // 이미지 업로드 (이미지가 있는 경우)
        let imageUrl = null;
        if (image) {
            const bucket = admin.storage().bucket();
            const imageFileName = `community/${userId}/${Date.now()}.jpg`;
            const file = bucket.file(imageFileName);

            // 파일 업로드
            await file.save(image.buffer, {
                metadata: {
                    contentType: image.mimetype
                }
            });

            // 파일 URL 생성
            await file.makePublic();
            imageUrl = `https://storage.googleapis.com/${bucket.name}/${imageFileName}`;
        }

        // 사용자 이름 가져오기
        const userName = userData.name || userData.email || '익명';

        // 커뮤니티 게시물 데이터 생성
        const postData = {
            userId,
            userName,
            title,
            content,
            imageUrl,
            recipe: recipeToShare,
            likedBy: [],
            comments: [],
            ratings: {},      // 평점 정보 초기화
            avgRating: 0,     // 평균 평점 초기화
            ratingCount: 0,   // 평점 개수 초기화
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        // Firestore에 게시물 저장
        const postRef = await db.collection('community').add(postData);

        // 사용자 문서에 작성한 게시물 ID 추가
        const userPosts = userData.posts || [];
        userPosts.push(postRef.id);
        await db.collection('user').doc(userId).update({
            posts: userPosts
        });

        res.status(201).json({
            success: true,
            message: '게시물이 성공적으로 작성되었습니다.',
            postId: postRef.id
        });

    } catch (error) {
        console.error('커뮤니티 게시물 작성 오류:', error);
        res.status(500).json({
            success: false,
            error: '게시물 작성 중 오류가 발생했습니다.'
        });
    }
});

// 커뮤니티 게시물 목록 조회 라우트
router.get('/community/posts', async (req, res) => {
    try {
        const { page = 1, limit = 10 } = req.query;
        const pageNumber = parseInt(page);
        const limitNumber = parseInt(limit);

        if (isNaN(pageNumber) || isNaN(limitNumber) || pageNumber < 1 || limitNumber < 1) {
            return res.status(400).json({
                success: false,
                error: '유효한 페이지 및 제한 수가 필요합니다.'
            });
        }

        const db = admin.firestore();
        const offset = (pageNumber - 1) * limitNumber;

        // 게시물 전체 개수 가져오기
        const countSnapshot = await db.collection('community').count().get();
        const totalCount = countSnapshot.data().count;

        // 최신 게시물부터 조회
        const postsSnapshot = await db.collection('community')
            .orderBy('createdAt', 'desc')
            .limit(limitNumber)
            .offset(offset)
            .get();

        const posts = [];
        postsSnapshot.forEach(doc => {
            const postData = doc.data();
            posts.push({
                id: doc.id,
                title: postData.title,
                content: postData.content,
                imageUrl: postData.recipe?.ATT_FILE_NO_MAIN || postData.imageUrl,
                userName: postData.userName,
                recipeName: postData.recipe?.RCP_NM || '레시피 없음',
                likeCount: (postData.likedBy || []).length,
                commentCount: (postData.comments || []).length,
                avgRating: postData.avgRating || 0,       // 평균 평점 추가
                ratingCount: postData.ratingCount || 0,
                createdAt: postData.createdAt?.toDate() || null
            });
        });

        res.json({
            success: true,
            posts,
            pagination: {
                total: totalCount,
                page: pageNumber,
                limit: limitNumber,
                totalPages: Math.ceil(totalCount / limitNumber)
            }
        });

    } catch (error) {
        console.error('커뮤니티 게시물 조회 오류:', error);
        res.status(500).json({
            success: false,
            error: '게시물 목록 조회 중 오류가 발생했습니다.'
        });
    }
});

// 게시물 상세 조회 라우트
router.get('/community/post/:postId', async (req, res) => {
    try {
        const { postId } = req.params;

        if (!postId) {
            return res.status(400).json({
                success: false,
                error: '게시물 ID가 필요합니다.'
            });
        }

        const db = admin.firestore();
        const postDoc = await db.collection('community').doc(postId).get();

        if (!postDoc.exists) {
            return res.status(404).json({
                success: false,
                error: '게시물을 찾을 수 없습니다.'
            });
        }

        const postData = postDoc.data();

        // 요청에 사용자 정보가 있는 경우 (로그인한 사용자)
        let userRating = null;
        if (req.user && req.user.uid) {
            userRating = postData.ratings ? postData.ratings[req.user.uid] || null : null;
        }

        // 좋아요 카운트 추가
        const likeCount = postData.likedBy ? postData.likedBy.length : 0;

        res.json({
            success: true,
            post: {
                id: postDoc.id,
                userId: postData.userId,
                userName: postData.userName,
                title: postData.title,
                content: postData.content,
                imageUrl: postData.imageUrl,
                recipe: postData.recipe,
                likedBy: postData.likedBy || [],
                comments: postData.comments || [],
                avgRating: postData.avgRating || 0,       // 평균 평점 추가
                ratingCount: postData.ratingCount || 0,   // 평점 개수 추가
                userRating: userRating,
                likeCount: likeCount, // 좋아요 카운트 추가
                createdAt: postData.createdAt?.toDate() || null
            }
        });

    } catch (error) {
        console.error('게시물 상세 조회 오류:', error);
        res.status(500).json({
            success: false,
            error: '게시물 조회 중 오류가 발생했습니다.'
        });
    }
});

// 게시물 좋아요 라우트
router.post('/community/post/:postId/like', authMiddleware, async (req, res) => {
    try {
        const { postId } = req.params;
        const userId = req.user.uid;

        if (!postId) {
            return res.status(400).json({
                success: false,
                error: '게시물 ID가 필요합니다.'
            });
        }

        const db = admin.firestore();
        const postRef = db.collection('community').doc(postId);
        const postDoc = await postRef.get();

        if (!postDoc.exists) {
            return res.status(404).json({
                success: false,
                error: '게시물을 찾을 수 없습니다.'
            });
        }

        const postData = postDoc.data();
        const likedBy = postData.likedBy || [];

        // 이미 좋아요를 눌렀는지 확인
        const alreadyLiked = likedBy.includes(userId);

        if (alreadyLiked) {
            // 좋아요 취소
            await postRef.update({
                likedBy: admin.firestore.FieldValue.arrayRemove(userId)
            });

            return res.json({
                success: true,
                message: '좋아요가 취소되었습니다.',
                liked: false
            });
        } else {
            // 좋아요 추가
            await postRef.update({
                likedBy: admin.firestore.FieldValue.arrayUnion(userId)
            });

            return res.json({
                success: true,
                message: '좋아요가 추가되었습니다.',
                liked: true
            });
        }

    } catch (error) {
        console.error('좋아요 처리 오류:', error);
        res.status(500).json({
            success: false,
            error: '좋아요 처리 중 오류가 발생했습니다.'
        });
    }
});

// 게시물 댓글 작성 라우트 수정
router.post('/community/post/:postId/comment', authMiddleware, async (req, res) => {
    try {
        const { postId } = req.params;
        const { content } = req.body;
        const userId = req.user.uid;

        if (!postId || !content) {
            return res.status(400).json({ error: '게시물 ID와 댓글 내용이 필요합니다.' });
        }

        const db = admin.firestore();
        const postRef = db.collection('community').doc(postId);
        const postDoc = await postRef.get();

        if (!postDoc.exists) {
            return res.status(404).json({ error: '게시물을 찾을 수 없습니다.' });
        }

        // 사용자 정보 가져오기
        const userDoc = await db.collection('user').doc(userId).get();
        if (!userDoc.exists) {
            return res.status(404).json({ error: '사용자 정보를 찾을 수 없습니다.' });
        }

        const userData = userDoc.data();
        const userName = userData.name || userData.email || '사용자';

        // 현재 시간을 Timestamp 객체로 생성 (serverTimestamp 대신)
        const timestamp = admin.firestore.Timestamp.now();

        // 댓글 데이터 생성
        const commentData = {
            userId,
            userName,
            content,
            createdAt: timestamp, // serverTimestamp() 대신 Timestamp.now() 사용
            commentId: `${postId}_${userId}_${Date.now()}`
        };

        // 게시물에 댓글 추가
        await postRef.update({
            comments: admin.firestore.FieldValue.arrayUnion(commentData)
        });

        res.status(201).json({
            success: true,
            message: '댓글이 등록되었습니다.',
            comment: commentData
        });

    } catch (error) {
        console.error('댓글 작성 오류:', error);
        res.status(500).json({
            error: '댓글 등록 중 오류가 발생했습니다.',
            details: error.message
        });
    }
});

// 게시물 삭제 라우트
router.delete('/community/post/:postId', authMiddleware, async (req, res) => {
    try {
        const { postId } = req.params;
        const userId = req.user.uid;

        if (!postId) {
            return res.status(400).json({
                success: false,
                error: '게시물 ID가 필요합니다.'
            });
        }

        const db = admin.firestore();
        const postRef = db.collection('community').doc(postId);
        const postDoc = await postRef.get();

        // 게시물 존재 확인
        if (!postDoc.exists) {
            return res.status(404).json({
                success: false,
                error: '게시물을 찾을 수 없습니다.'
            });
        }

        const postData = postDoc.data();

        // 게시물 작성자 확인
        if (postData.userId !== userId) {
            return res.status(403).json({
                success: false,
                error: '자신이 작성한 게시물만 삭제할 수 있습니다.'
            });
        }

        // 이미지가 있는 경우 Storage에서 삭제
        if (postData.imageUrl) {
            try {
                const bucket = admin.storage().bucket();
                const imageFileName = postData.imageUrl.split('/').pop();
                const file = bucket.file(`community/${userId}/${imageFileName}`);
                await file.delete();
            } catch (imageError) {
                console.error('이미지 삭제 오류:', imageError);
                // 이미지 삭제 실패해도 게시물 삭제는 계속 진행
            }
        }

        // 사용자 문서에서 게시물 ID 제거
        const userRef = db.collection('user').doc(userId);
        const userDoc = await userRef.get();

        if (userDoc.exists) {
            const userData = userDoc.data();
            const userPosts = userData.posts || [];
            const updatedPosts = userPosts.filter(id => id !== postId);

            await userRef.update({
                posts: updatedPosts
            });
        }

        // 게시물 삭제
        await postRef.delete();

        res.json({
            success: true,
            message: '게시물이 성공적으로 삭제되었습니다.'
        });

    } catch (error) {
        console.error('게시물 삭제 오류:', error);
        res.status(500).json({
            success: false,
            error: '게시물 삭제 중 오류가 발생했습니다.'
        });
    }
});

// 게시물 레이팅 라우트
router.post('/community/post/:postId/rating', authMiddleware, async (req, res) => {
    try {
        const { postId } = req.params;
        const { rating } = req.body;
        const userId = req.user.uid;

        // 유효성 검사
        if (!postId) {
            return res.status(400).json({
                success: false,
                error: '게시물 ID가 필요합니다.'
            });
        }

        // 평점 유효성 검사
        const ratingValue = parseFloat(rating);
        if (isNaN(ratingValue) || ratingValue < 1 || ratingValue > 5) {
            return res.status(400).json({
                success: false,
                error: '평점은 1에서 5 사이의 숫자여야 합니다.'
            });
        }

        const db = admin.firestore();
        const postRef = db.collection('community').doc(postId);
        const postDoc = await postRef.get();

        if (!postDoc.exists) {
            return res.status(404).json({
                success: false,
                error: '게시물을 찾을 수 없습니다.'
            });
        }

        const postData = postDoc.data();
        const ratings = postData.ratings || {};

        // 새 평점 정보 갱신
        ratings[userId] = ratingValue;

        // 평균 평점 계산
        const ratingValues = Object.values(ratings);
        const avgRating = ratingValues.reduce((sum, val) => sum + val, 0) / ratingValues.length;

        // Firestore 업데이트
        await postRef.update({
            ratings: ratings,
            avgRating: avgRating,
            ratingCount: ratingValues.length
        });

        return res.json({
            success: true,
            message: '평점이 성공적으로 저장되었습니다.',
            avgRating: avgRating,
            ratingCount: ratingValues.length
        });

    } catch (error) {
        console.error('평점 처리 오류:', error);
        res.status(500).json({
            success: false,
            error: '평점 처리 중 오류가 발생했습니다.'
        });
    }
});

// 댓글 수정 라우트
router.put('/community/post/:postId/comment/:commentId', authMiddleware, async (req, res) => {
    try {
        const { postId, commentId } = req.params;
        const { content } = req.body;
        const userId = req.user.uid;

        if (!postId || !commentId || !content) {
            return res.status(400).json({
                success: false,
                error: '게시물 ID, 댓글 ID, 댓글 내용이 모두 필요합니다.'
            });
        }

        const db = admin.firestore();
        const postRef = db.collection('community').doc(postId);
        const postDoc = await postRef.get();

        if (!postDoc.exists) {
            return res.status(404).json({
                success: false,
                error: '게시물을 찾을 수 없습니다.'
            });
        }

        const postData = postDoc.data();
        const comments = postData.comments || [];

        // 댓글 찾기
        const commentIndex = comments.findIndex(comment => comment.commentId === commentId);

        if (commentIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '댓글을 찾을 수 없습니다.'
            });
        }

        // 댓글 작성자 확인
        if (comments[commentIndex].userId !== userId) {
            return res.status(403).json({
                success: false,
                error: '자신이 작성한 댓글만 수정할 수 있습니다.'
            });
        }

        // 댓글 내용 업데이트
        comments[commentIndex].content = content;
        comments[commentIndex].updatedAt = admin.firestore.Timestamp.now();

        await postRef.update({ comments });

        res.json({
            success: true,
            message: '댓글이 성공적으로 수정되었습니다.',
            comment: comments[commentIndex]
        });

    } catch (error) {
        console.error('댓글 수정 오류:', error);
        res.status(500).json({
            success: false,
            error: '댓글 수정 중 오류가 발생했습니다.'
        });
    }
});

// 댓글 삭제 라우트
router.delete('/community/post/:postId/comment/:commentId', authMiddleware, async (req, res) => {
    try {
        const { postId, commentId } = req.params;
        const userId = req.user.uid;

        if (!postId || !commentId) {
            return res.status(400).json({
                success: false,
                error: '게시물 ID와 댓글 ID가 필요합니다.'
            });
        }

        const db = admin.firestore();
        const postRef = db.collection('community').doc(postId);
        const postDoc = await postRef.get();

        if (!postDoc.exists) {
            return res.status(404).json({
                success: false,
                error: '게시물을 찾을 수 없습니다.'
            });
        }

        const postData = postDoc.data();
        const comments = postData.comments || [];

        // 댓글 찾기
        const commentIndex = comments.findIndex(comment => comment.commentId === commentId);

        if (commentIndex === -1) {
            return res.status(404).json({
                success: false,
                error: '댓글을 찾을 수 없습니다.'
            });
        }

        // 댓글 작성자 확인
        if (comments[commentIndex].userId !== userId) {
            return res.status(403).json({
                success: false,
                error: '자신이 작성한 댓글만 삭제할 수 있습니다.'
            });
        }

        // 댓글 삭제
        comments.splice(commentIndex, 1);

        await postRef.update({ comments });

        res.json({
            success: true,
            message: '댓글이 성공적으로 삭제되었습니다.'
        });

    } catch (error) {
        console.error('댓글 삭제 오류:', error);
        res.status(500).json({
            success: false,
            error: '댓글 삭제 중 오류가 발생했습니다.'
        });
    }
});


module.exports = router;